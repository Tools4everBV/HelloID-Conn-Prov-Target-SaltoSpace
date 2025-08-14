Mit Hilfe des Salto Space Target Connectors verbinden Sie Salto Space über die Identity- & Accessmanagement-Lösung (IAM) HelloID von Tools4ever mit verschiedenen Quellsystemen. Diese Integration bietet zahlreiche Vorteile und optimiert unter anderem die Verwaltung von Zugriffsrechten und Benutzerkonten. Automatisierung steht dabei im Mittelpunkt, was Ihnen viel Arbeit abnimmt und menschliche Fehler verhindert. HelloID basiert stets auf Daten, die es aus Ihren Quellsystemen abruft. In diesem Artikel erläutern wir die Möglichkeiten und Vorteile des Salto Space Target Connectors.

## Was ist Salto Space?

Salto Space ist eine vollständig integrierte, intelligente Zutrittskontrollplattform, entwickelt von Salto Systems. Die Plattform ist eigenständig und webbasiert. Sie umfasst Managementsoftware für das sichere und effiziente Verwalten des Zugangs zu Türen in einem Gebäude. Das System ist für eine drahtlose Umgebung konzipiert. Daher ist es nicht nötig, Zugangspunkte in einem Gebäude zu verkabeln, und es kann auf bestehenden Türen und Schlössern angewendet werden. Salto Space bietet gleichzeitig auch Unterstützung für verkabelte Schlösser. Benutzer können Türen unter anderem mit ihrem Smartphone, PIN-Code oder Smart-Keycard öffnen.

## Warum ist die Verbindung mit Salto Space nützlich?

Bei der Ermöglichung optimaler Produktivität denken Sie vielleicht schnell daran, den richtigen Zugang zu Software, Datenbanken und Cloudanwendungen und -systemen bereitzustellen. Mindestens ebenso wichtig ist jedoch der physische Zugang zum Unternehmensgebäude oder zu Räumen, in denen ein Mitarbeiter tätig wird. Wer das Gebäude nicht betreten kann, kann schließlich nicht arbeiten. Salto Space stellt diesen Zugang über ein webbasiertes System bereit. Mit Hilfe des Salto Space Target Connectors verbinden Sie Salto Space über HelloID mit Ihren Quellsystemen. Dies bedeutet, dass die IAM-Lösung von Tools4ever basierend auf Ihrem Quellsystem dafür sorgt, dass die richtigen Personen Zugang zu den richtigen Türen haben und beispielsweise ein Unternehmensgebäude oder spezifische Räume innerhalb dieses Gebäudes betreten können.

Sie können als Administrator auch direkt in Salto Space Konten und Rechte verwalten, wobei Sie benutzerspezifisch manuell die richtigen Zugriffsrechte einstellen. HelloID ist eine Alternative und automatisiert diesen Prozess in hohem Maße mit Hilfe von Business Rules. So können Sie Mitarbeitern basierend auf ihrer Funktion Zugang zu allen benötigten Räumen gewähren, ohne dass dafür manuelle Maßnahmen erforderlich sind. Sind Anpassungen für einzelne Benutzer notwendig? Dann erledigen Sie dies einfach über das Service Automation-Modul von HelloID.

Die Verbindung spart Ihnen damit viel Zeit, sorgt für eine einheitliche Arbeitsweise und verhindert menschliche Fehler. So stellen Sie sicher, dass Mitarbeiter nur Zugang zu den Bereichen erhalten, zu denen sie berechtigt sind, was die physische Sicherheit in Ihrem Gebäude erhöht. In der Praxis müssen Sie nur noch die physischen Karten, Chips und/oder Tags manuell konfigurieren und Mitarbeitern aushändigen; die Zuweisung der richtigen Zugriffsrechte erfolgt automatisch.

Mithilfe des Salto Space Connectors können Sie Integrationen mit gängigen Systemen realisieren. Beispiele sind:

* AFAS

* Visma Raet

Über die Verbindung mit diesen Quellsystemen erfahren Sie weiter unten in diesem Artikel mehr.

## Wie HelloID mit Salto Space integriert

Sie können Salto Space als Zielsystem in HelloID integrieren. Wir setzen den Salto Space Connector als Zielconnector ein. Der Connector ermöglicht die Verwaltung von Benutzerkonten sowie der zugehörigen Zugriffsgruppen. Mithilfe von Zugriffsgruppen können Sie die Zugriffsrechte einer Benutzergruppe auf einen Schlag verwalten.

Der Datenaustausch zwischen HelloID und Salto Space erfolgt über eine Staging-SQL-Tabelle; Aktionen sind in der Datenbank von Salto Space nicht direkt ausführbar. Das bedeutet, dass HelloID alle Aktionen in die Staging-Tabelle schreibt, die Salto Space regelmäßig ausliest. Dieser Prozess erfordert eine korrekte Konfiguration von Salto Space. Basierend auf der Personalnummer eines Mitarbeiters kann Salto Space ein bestehendes Salto Space-Konto korrelieren.

Achtung: Der Salto Space Target Connector ist ein komplexer Connector. Wir empfehlen daher stets, sich mit Tools4ever in Verbindung zu setzen, um diesen Connector zu implementieren. Unsere Experten stehen bereit, um Sie zu unterstützen!

**Automatisches Erstellen und Aktualisieren des benötigten Kontos**
Tritt ein neuer Mitarbeiter in Ihr Unternehmen ein, erstellt HelloID automatisch ein Konto in Salto Space. Mitarbeiter können dadurch sofort loslegen. Ändern sich Daten eines Mitarbeiters in Ihrem Quellsystem? Dann passt HelloID das Konto automatisch an. Basierend auf den Quelldaten aktualisiert HelloID dies zusätzlich im Lifecycle der IAM-Lösung.

**Salto Space (limitiert) Zugriffsgruppen zuweisen oder entziehen**
HelloID kann basierend auf Quelldaten einen Benutzer einer (limitierten) Zugriffsgruppe zuweisen oder diese entziehen. So stellen Sie sicher, dass Zugriffsrechte stets aktuell sind.

Benutzerkonten in Salto Space sind mit verschiedenen frei zu befüllenden Feldern ausgestattet. HelloID kann Daten aus Ihrem Quellsystem in diese Felder abbilden.

## HelloID für Salto Space unterstützt Sie bei

* **Schneller Erstellen von Konten:** Durch die Verbindung von Salto Space mit Ihren Quellsystemen erstellt HelloID automatisch ein Benutzerkonto in Salto Space basierend auf den Daten Ihrer Quellsysteme. So stellen Sie sicher, dass ein neuer Mitarbeiter direkt am ersten Tag physischen Zugang zu den benötigten Räumen hat.

* **Fehlerfreies Kontenmanagement:** Die Verbindung sorgt für Konsistenz im Benutzerkontenmanagement. HelloID verwendet feste Verfahren für die Kontobereitstellung, bei denen Sie die Kontrolle haben. So stellen Sie sicher, dass Sie stets vollständig den geltenden Compliance-Anforderungen entsprechen und verhindern darüber hinaus menschliche Fehler. Angenehm, denn wenn Mitarbeiter nicht die richtigen Zugangsrechte haben, kann das unangenehme Folgen haben. Können Mitarbeiter einen benötigten Raum nicht betreten? Dann beeinträchtigt das die Produktivität. Gewähren Sie Mitarbeitern jedoch zu viel Zugang? Dann kann das die physische Sicherheit Ihres Unternehmens beeinflussen.

* **Verbessern von Serviceniveaus und Stärken Ihrer Sicherheit:** Die Verbindung zwischen Ihren Quellsystemen und Salto Space hebt Ihre Sicherheit auf ein höheres Niveau. Sie stellen unter anderem sicher, dass Mitarbeiter nie mehr Zugang haben als notwendig, was die Auswirkungen begrenzt, wenn beispielsweise ein Smartphone oder eine Keycard gestohlen wird. Gleichzeitig erhöhen Sie Ihr Serviceniveau, da Mitarbeiter stets zum richtigen Zeitpunkt über den richtigen physischen Zugang verfügen. Dies verhindert Frustration und erhöht die Mitarbeiterzufriedenheit.

## Salto Space über HelloID mit Systemen koppeln

Über HelloID können Sie verschiedene Quellsysteme mit Salto Space integrieren. Die Verbindungen heben das Management von Benutzerkonten und den physischen Zugang zu Ihrem Gebäude auf ein höheres Niveau. Beispiele für häufige Integrationen sind:

* **AFAS - Salto Space Verbindung:** Mithilfe der AFAS - Salto Space Verbindung stärken Sie die Zusammenarbeit zwischen Ihrer HR- und IT-Abteilung. So kann HelloID bei der Einstellung eines neuen Mitarbeiters automatisch einen Benutzer in Salto Space erstellen und diesen der zugehörigen (limitierten) Zugriffsgruppe zuordnen. Sie gestalten den Kontobereitstellungsprozess so reibungslos und effizient.

* **Visma Raet - Salto Space Verbindung:** Die Visma Raet - Salto Space Verbindung ermöglicht es, alle relevanten Informationen aus dem HR-System von Visma abzurufen und basierend darauf in Salto Space die benötigten Benutzerkonten und Berechtigungen zu erstellen. HelloID automatisiert diesen Prozess vollständig und leitet den Prozess als Vermittler in geordnete Bahnen.

HelloID bietet Unterstützung für über 200 verschiedene Connectoren. Die IAM-Lösung bietet damit ein breites Spektrum an Integrationsmöglichkeiten zwischen Ihren Quellsystemen und Salto Space. Unser Portfolio an Connectoren und Integrationen entwickelt sich kontinuierlich weiter und wächst kontinuierlich. Sie können HelloID somit an nahezu jedes beliebte System koppeln.