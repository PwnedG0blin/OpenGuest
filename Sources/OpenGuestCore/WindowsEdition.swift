import Foundation

public enum WindowsEdition {
    public struct LocalAccount {
        public let name: String
        public let password: String
        public init(name: String, password: String) { self.name = name; self.password = password }
    }
    public static func setupXML(selectPro: Bool, localAccount: LocalAccount?) throws -> String {
        var settings = ""
        if selectPro {
            settings = answerFile.replacingOccurrences(of: "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n", with: "")
                .replacingOccurrences(of: "<unattend xmlns=\"urn:schemas-microsoft-com:unattend\">", with: "")
                .replacingOccurrences(of: "</unattend>", with: "")
        }
        if let account = localAccount {
            let invalid = CharacterSet(charactersIn: "\"/\\[]:;|=,+*?<>@")
            guard (1...20).contains(account.name.count), !account.name.hasSuffix("."),
                  account.name == account.name.trimmingCharacters(in: .whitespacesAndNewlines),
                  !account.name.unicodeScalars.contains(where: { invalid.contains($0) || CharacterSet.controlCharacters.contains($0) }),
                  !["administrator", "guest", "defaultaccount", "wdagutilityaccount"].contains(account.name.lowercased()),
                  account.password.count >= 8 else {
                throw NSError(domain: "OpenGuest.Windows", code: 2, userInfo: [NSLocalizedDescriptionKey: "Lokalen Benutzernamen (1–20 Zeichen) und Passwort (mindestens 8 Zeichen) prüfen."])
            }
            let name = account.name.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;")
            // Windows answer-file encoding is reversible; this is NOT encryption.
            let encoded = (account.password + "Password").data(using: .utf16LittleEndian)!.base64EncodedString()
            settings += """
            <settings pass="oobeSystem">
              <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="arm64"
                         publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
                <OOBE><HideOnlineAccountScreens>true</HideOnlineAccountScreens><HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE></OOBE>
                <UserAccounts><LocalAccounts>
                  <LocalAccount xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" wcm:action="add">
                    <Password><Value>\(encoded)</Value><PlainText>false</PlainText></Password>
                    <DisplayName>\(name)</DisplayName><Group>Administrators</Group><Name>\(name)</Name>
                  </LocalAccount>
                </LocalAccounts></UserAccounts>
              </component>
            </settings>
            """
        }
        return "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<unattend xmlns=\"urn:schemas-microsoft-com:unattend\">\n" + settings + "\n</unattend>\n"
    }
    // Only select the Pro image. Do not set a key, partition disks, skip OOBE,
    // create accounts, accept the license or bypass hardware requirements.
    public static let answerFile = """
    <?xml version="1.0" encoding="utf-8"?>
    <unattend xmlns="urn:schemas-microsoft-com:unattend">
      <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="arm64"
                   publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
          <ImageInstall>
            <OSImage>
              <InstallFrom>
                <MetaData xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" wcm:action="add">
                  <Key>/IMAGE/NAME</Key>
                  <Value>Windows 11 Pro</Value>
                </MetaData>
              </InstallFrom>
            </OSImage>
          </ImageInstall>
        </component>
      </settings>
    </unattend>
    """
}
