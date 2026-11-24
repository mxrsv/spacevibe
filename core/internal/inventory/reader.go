package inventory

import (
	"context"
	"path/filepath"
	"strconv"
	"strings"

	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/hashes"
	"spacevibe.dev/core/internal/ojson"
	"spacevibe.dev/core/internal/roots"
	"spacevibe.dev/core/internal/textjs"
	"spacevibe.dev/core/internal/toml"
)

// Read lists the skills, agents and hooks of both CLIs, plugin-owned items, and the .claude folders of the
// discovered projects. Every file that cannot be used becomes a plain sentence in Problems; nothing here
// fails. It reads the disk synchronously. Ported from Inventory.read.
func Read(r roots.Roots) Snapshot {
	snapshot, _, _ := read(context.Background(), r)
	return snapshot
}

// read is Read plus the project folders it discovered, for the process-wide list (see Service). It looks at
// the context between the CLIs, plugins and projects and returns its error when it ended.
func read(ctx context.Context, r roots.Roots) (Snapshot, []string, error) {
	var (
		items    []Item
		hooks    []Hook
		problems []string
		// otherHooks counts hooks of a type other than command (http, mcp_tool, prompt, agent), which are not listed.
		otherHooks int
		// unreadable is what could not be looked at, per CLI and kind (cli-cells.go).
		unreadable unreadableKinds
		// folders are the global folders and hook files of each CLI that is there (readers-map.go).
		folders []Folder
		// shared and sharedProblems are the Codex skills of ~/.agents/skills and the lines about that folder: only
		// loadout.rows' extra fields carry them (readers-map.go).
		shared         []Item
		sharedProblems []string
	)
	clis := []struct {
		cli CLI
		r   roots.CLIRoots
	}{{Claude, r.Claude}, {Codex, r.Codex}}
	for _, c := range clis {
		if err := ctx.Err(); err != nil {
			return Snapshot{}, nil, err
		}
		switch fsx.PathPresence(c.r.Root) {
		case fsx.Missing:
			continue
		case fsx.Unknown:
			problems = append(problems, c.r.Root+" cannot be read, so its skills, agents and hooks cannot be shown.")
			unreadable = unreadable.mark(c.cli, KindSkill, KindAgent, KindHook)
			continue
		}
		skills, skillsUnreadable := readSkills(c.r.Skills, c.cli, nil, nil, &problems)
		agents, agentsUnreadable := readAgents(c.r.Agents, c.cli, nil, nil, &problems)
		items = append(append(items, skills...), agents...)
		unreadable = unreadable.markIf(skillsUnreadable, c.cli, KindSkill).markIf(agentsUnreadable, c.cli, KindAgent)
		folders = append(folders, ownFolders(c.cli, c.r)...)
		if c.cli == Codex {
			// Codex also reads the shared ~/.agents/skills (readers-map.go); only while its own folder is there. Its
			// skills and problem lines stay out of every field the v5 shell decodes until RB-X1 (plan AR1).
			found, foundUnreadable := readSkills(r.AgentsSkills, Codex, nil, nil, &sharedProblems)
			shared = sharedSkills(found)
			unreadable = unreadable.markIf(foundUnreadable, Codex, KindSkill)
			folders = append(folders, agentsSkillsFolder(r.AgentsSkills))
		}
		config, status := readJSON(c.r.HookFile)
		unreadable = unreadable.markIf(unusableReason(status) != "", c.cli, KindHook)
		switch status {
		case jsonValue:
			hooks = append(hooks, parseHooks(config, c.cli, nil, c.r.HookFile, nil, &problems, &otherHooks)...)
		case jsonInvalid:
			problems = append(problems, c.r.HookFile+" is not valid JSON, so its hooks cannot be shown or changed.")
		case jsonTooLarge:
			problems = append(problems, c.r.HookFile+" is too large to read, so its hooks cannot be shown.")
		case jsonUnreadable:
			problems = append(problems, c.r.HookFile+" cannot be read, so its hooks cannot be shown.")
		}
	}

	claudeSettings, settingsStatus := readJSON(r.Claude.HookFile)
	haveSettings := settingsStatus == jsonValue
	if reason := unusableReason(settingsStatus); reason != "" {
		// The hooks loop above already says the file cannot be used for hooks; this is what else depends on it.
		problems = append(problems, r.Claude.HookFile+" "+reason+", so enabled plugins and skill overrides are not known.")
	}
	enabledPlugins, pluginsKnown := plugins(r, claudeSettings, settingsStatus, &problems)
	unreadable = unreadable.markIf(!pluginsKnown, Claude, KindSkill, KindAgent, KindHook)
	for _, plugin := range enabledPlugins {
		if err := ctx.Err(); err != nil {
			return Snapshot{}, nil, err
		}
		owner := plugin.name
		base := absolute(plugin.path)
		skills, skillsUnreadable := readSkills(textjs.JoinPath(base, "skills"), Claude, &owner, nil, &problems)
		agents, agentsUnreadable := readAgents(textjs.JoinPath(base, "agents"), Claude, &owner, nil, &problems)
		items = append(append(items, skills...), agents...)
		unreadable = unreadable.markIf(skillsUnreadable, Claude, KindSkill).markIf(agentsUnreadable, Claude, KindAgent)
		hookFile := textjs.JoinPath(base, "hooks", "hooks.json")
		config, status := readJSON(hookFile)
		unreadable = unreadable.markIf(unusableReason(status) != "", Claude, KindHook)
		if status == jsonValue {
			hooks = append(hooks, parseHooks(config, Claude, &owner, hookFile, nil, &problems, &otherHooks)...)
		} else if reason := unusableReason(status); reason != "" {
			problems = append(problems, hookFile+" "+reason+", so the hooks of the plugin "+owner+" are not shown.")
		}
	}

	projects := discoverProjects(ctx, r)
	for _, path := range projects {
		if err := ctx.Err(); err != nil {
			return Snapshot{}, nil, err
		}
		project := path
		dir := textjs.JoinPath(path, ".claude")
		if fsx.PathPresence(dir) == fsx.Unknown {
			problems = append(problems, path+" cannot be read, so its skills, agents and hooks cannot be shown.")
			continue
		}
		// A project row holds Claude items only, so an unreadable project folder leaves no row whose Claude cell
		// could read unknown: the problem line is all there is to say.
		skills, _ := readSkills(textjs.JoinPath(dir, "skills"), Claude, nil, &project, &problems)
		agents, _ := readAgents(textjs.JoinPath(dir, "agents"), Claude, nil, &project, &problems)
		items = append(append(items, skills...), agents...)
		for _, name := range []string{"settings.json", "settings.local.json"} {
			file := textjs.JoinPath(dir, name)
			config, status := readJSON(file)
			switch status {
			case jsonValue:
				hooks = append(hooks, parseHooks(config, Claude, nil, file, &project, &problems, &otherHooks)...)
			case jsonInvalid:
				problems = append(problems, file+" is not valid JSON, so its hooks cannot be shown.")
			case jsonTooLarge:
				problems = append(problems, file+" is too large to read, so its hooks cannot be shown.")
			case jsonUnreadable:
				problems = append(problems, file+" cannot be read, so its hooks cannot be shown.")
			}
		}
	}

	// Claude global skills carry the skillOverrides value of settings.json (nil when there is none).
	var overrides ojson.Value
	haveOverrides := false
	if haveSettings {
		overrides, haveOverrides = claudeSettings.Member("skillOverrides")
	}
	for i := range items {
		item := &items[i]
		if item.CLI == Claude && item.Kind == KindSkill && item.Scope == ScopeGlobal {
			item.HasSkillOverride = true
			item.SkillOverride = nil
			if haveOverrides {
				if v, ok := overrides.Member(item.Name); ok {
					if s, ok := v.StringValue(); ok {
						item.SkillOverride = &s
					}
				}
			}
		}
	}

	names := map[string]struct{}{}
	for _, item := range items {
		names[string(item.CLI)+":"+item.Key()] = struct{}{}
	}
	for i := range items {
		_, items[i].InOther = names[string(items[i].CLI.Other())+":"+items[i].Key()]
	}
	// The v5 items above never count a shared skill; a shared skill's inOther looks at the v5 items (all Claude's).
	for i := range shared {
		_, shared[i].InOther = names[string(shared[i].CLI.Other())+":"+shared[i].Key()]
	}

	if otherHooks == 1 {
		problems = append(problems, "1 hook of another type is not shown.")
	} else if otherHooks > 1 {
		problems = append(problems, strconv.Itoa(otherHooks)+" hooks of other types are not shown.")
	}

	if items == nil {
		items = []Item{}
	}
	if hooks == nil {
		hooks = []Hook{}
	}
	if problems == nil {
		problems = []string{}
	}
	if err := ctx.Err(); err != nil {
		return Snapshot{}, nil, err
	}
	return Snapshot{
		Items: items, Hooks: hooks, Problems: problems, Events: Events(),
		Roots:      map[string]string{string(Claude): r.Claude.Root, string(Codex): r.Codex.Root},
		unreadable: unreadable, folders: folders, shared: shared, sharedProblems: sharedProblems,
	}, projects, nil
}

// ItemFile is the text of a skill or agent file for the detail view, capped.
type ItemFile struct {
	Size      int64  `json:"size"`
	Text      string `json:"text"`
	Truncated bool   `json:"truncated"`
}

// ReadItemFile is the first 64 KB of a skill or agent file for the detail view. False when it cannot be read.
func ReadItemFile(path string) (ItemFile, bool) {
	info, err := osStat(path)
	if err != nil {
		return ItemFile{}, false
	}
	text, ok := readText(path, itemFileBytes)
	if !ok {
		return ItemFile{}, false
	}
	return ItemFile{Size: info.Size(), Text: text, Truncated: info.Size() > itemFileBytes}, true
}

func absolute(path string) string {
	if filepath.IsAbs(path) {
		return strings.TrimRight(path, "/")
	}
	abs, err := filepath.Abs(path)
	if err != nil {
		return path
	}
	return abs
}

// Skills and agents.

// readSkills lists the skills of one folder. folderUnreadable is true when the folder itself cannot be listed
// (a problem line says so), which makes a skill absent from it unknown rather than missing.
func readSkills(dir string, cli CLI, owner, project *string, problems *[]string) (out []Item, folderUnreadable bool) {
	folderUnreadable = isUnreadableFolder(dir)
	if folderUnreadable {
		*problems = append(*problems, dir+" cannot be read, so its skills cannot be shown.")
	}
	for _, entry := range listDir(dir) {
		if isSystemName(entry) {
			continue
		}
		path := textjs.JoinPath(dir, entry)
		file := textjs.JoinPath(path, "SKILL.md")
		text, ok := readText(file, maxTextBytes)
		if !ok {
			if fsx.PathPresence(file) != fsx.Missing {
				*problems = append(*problems, file+" cannot be read, so this skill is not shown.")
			}
			continue
		}
		fm := ParseFrontmatter(text)
		out = append(out, Item{
			ID: string(cli) + ":skill:" + idTag(owner, project) + ":" + entry, CLI: cli, Kind: KindSkill,
			Name: nonEmpty(fm["name"], entry), Entry: entry, Description: fm["description"],
			Owner: ownerOf(owner, path), Path: path, File: file, Removable: isUserLevel(owner, project),
			Scope: scopeOf(project), Project: project,
		})
	}
	return out, folderUnreadable
}

// readAgents is readSkills for subagents.
func readAgents(dir string, cli CLI, owner, project *string, problems *[]string) (out []Item, folderUnreadable bool) {
	folderUnreadable = isUnreadableFolder(dir)
	if folderUnreadable {
		*problems = append(*problems, dir+" cannot be read, so its agents cannot be shown.")
	}
	for _, entry := range listDir(dir) {
		if isSystemName(entry) {
			continue
		}
		isMarkdown := strings.HasSuffix(entry, ".md")
		if !isMarkdown && !strings.HasSuffix(entry, ".toml") {
			continue
		}
		path := textjs.JoinPath(dir, entry)
		text, ok := readText(path, maxTextBytes)
		if !ok {
			*problems = append(*problems, path+" cannot be read, so this agent is not shown.")
			continue
		}
		var fields map[string]string
		fallback := strings.TrimSuffix(entry, ".toml")
		if isMarkdown {
			fields = ParseFrontmatter(text)
			fallback = strings.TrimSuffix(entry, ".md")
		} else {
			fields = tomlFields(text)
		}
		out = append(out, Item{
			ID: string(cli) + ":agent:" + idTag(owner, project) + ":" + entry, CLI: cli, Kind: KindAgent,
			Name: nonEmpty(fields["name"], fallback), Entry: entry, Description: fields["description"],
			Owner: ownerOf(owner, path), Path: path, File: path, Removable: isUserLevel(owner, project),
			Scope: scopeOf(project), Project: project,
		})
	}
	return out, folderUnreadable
}

// tomlFields are the name and description of a Codex agent .toml: the first assignment of each key, in any
// table, as the Node regex finds it.
func tomlFields(text string) map[string]string {
	doc := toml.Read(text)
	out := map[string]string{}
	for _, key := range []string{"name", "description"} {
		for _, e := range doc.Entries {
			if len(e.KeyPath) == 1 && e.KeyPath[0] == key && e.Value != nil {
				if s, ok := e.Value.AsString(); ok {
					out[key] = s
					break
				}
			}
		}
	}
	return out
}

func isSystemName(name string) bool {
	return strings.HasPrefix(name, ".") || strings.HasPrefix(name, "_")
}

func nonEmpty(s, fallback string) string {
	if s == "" {
		return fallback
	}
	return s
}

func isUserLevel(owner, project *string) bool {
	return (owner == nil || *owner == "") && project == nil
}

func ownerOf(owner *string, path string) string {
	if owner != nil {
		return *owner
	}
	if isSymlink(path) {
		return "link"
	}
	return "user"
}

func scopeOf(project *string) Scope {
	if project == nil {
		return ScopeGlobal
	}
	return ScopeProject
}

func idTag(owner, project *string) string {
	if project != nil {
		return "project:" + hashes.Sha(*project)
	}
	if owner != nil {
		return *owner
	}
	return "local"
}
