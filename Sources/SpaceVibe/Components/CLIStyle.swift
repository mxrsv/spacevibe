/// A CLI's name and look, read from `CLIRegistry` (MC-R1). Views write `cli.label` or `cli.identity.tone`; the facts live in
/// the registry only.
extension CoreCLI {
    var identity: CLIIdentity { CLIRegistry.identity(self) }
    /// The CLI's name as the app writes it (GLOSSARY).
    var label: String { identity.label }
}

extension CoreLimitsCLI {
    var identity: CLIIdentity { CLIRegistry.identity(self) }
    /// The CLI's name as the app writes it (GLOSSARY).
    var label: String { identity.label }
}
