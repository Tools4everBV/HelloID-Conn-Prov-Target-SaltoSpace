
Grâce au connecteur cible Salto Space, vous pouvez connecter Salto Space à divers systèmes sources via la solution de gestion des identités et des accès (GIA) HelloID de Tools4ever. Cette intégration présente de nombreux avantages, notamment en simplifiant la gestion des droits d'accès et des comptes utilisateurs. L’automatisation est au cœur de ce processus, réduisant considérablement le travail manuel et éliminant les erreurs humaines. HelloID se base toujours sur les données extraites de vos systèmes sources. Cet article détaille les fonctionnalités et les avantages du connecteur cible Salto Space. 

## Qu’est-ce que Salto Space ?

Salto Space est une solution complète et intelligente de contrôle d'accès, conçue par Salto Systems. Ce système web autonome offre un outil de gestion centralisé pour superviser de manière sécurisée et efficace l’accès aux portes d’un bâtiment. Son architecture sans fil permet de l’installer sur des portes et serrures existantes, sans nécessiter de câblage supplémentaire. Salto Space prend également en charge des serrures câblées et permet aux utilisateurs d’ouvrir les portes avec un smartphone, un code PIN ou une carte clé intelligente.

## Pourquoi intégrer Salto Space ?

Lorsque vous cherchez à maximiser la productivité, vous pensez probablement à garantir l'accès à des outils numériques tels que des logiciels, bases de données ou systèmes cloud. Mais il ne faut pas oublier l’importance de l’accès physique aux bâtiments ou aux espaces de travail. Si un membre du personnel ne peut pas accéder à son bureau, il ne pourra pas accomplir ses tâches.

Salto Space offre un système web intuitif pour gérer ces accès physiques. Vous pouvez configurer les droits d'accès directement dans Salto Space, mais cela implique des mises à jour manuelles, utilisateur par utilisateur. Avec HelloID, ce processus est largement automatisé grâce à des règles métier (business rules). Ainsi, les employés obtiennent automatiquement les droits d'accès requis en fonction de leur poste ou rôle, sans intervention manuelle.

Les ajustements spécifiques à certains utilisateurs peuvent être facilement réalisés via le module Service Automation d’HelloID. En connectant Salto Space à vos systèmes sources, HelloID garantit que chaque collaborateur dispose des accès nécessaires aux espaces de travail ou aux bâtiments qui lui sont assignés. Cette automatisation réduit les tâches administratives, uniformise les processus et élimine les erreurs humaines, tout en renforçant la sécurité.

Concrètement, vous n’aurez qu’à configurer et distribuer physiquement les badges, clés ou cartes aux employés. Le reste, la gestion des droits d'accès, est pris en charge automatiquement par HelloID.

Le connecteur cible Salto Space vous permet de relier cette solution à différents systèmes sources courants, comme par exemple : 

*	ADP
*	CPage
*	SAP
*	Antibia
*	Luccas
*	Pléiade
*	CIRILL
*	Etc.

Vous trouverez davantage d’informations sur ces intégrations dans les sections suivantes de cet article.

## Intégration d'HelloID avec Salto Space

Vous pouvez intégrer Salto Space comme système cible avec HelloID en utilisant le connecteur cible Salto Space. Cette intégration facilite la gestion des comptes utilisateurs et des groupes d’accès associés. Les groupes d’accès permettent de gérer en une seule fois les droits d’accès pour plusieurs utilisateurs.

L’échange de données entre HelloID et Salto Space se fait via une table de staging SQL. Les actions ne sont pas exécutées directement dans la base de données de Salto Space. Concrètement, HelloID inscrit toutes les actions dans cette table intermédiaire, que Salto Space consulte périodiquement. Cette configuration nécessite une configuration depuis Salto Space. Sur la base du numéro de personnel d’un employé (matricule), Salto Space peut corréler un compte existant avec les données HelloID.

Important : Le connecteur cible Salto Space est une intégration complexe. Nous vous recommandons vivement de contacter Tools4ever pour l’implémentation de cette solution. Nos experts sont prêts à vous accompagner !

**Création et mise à jour automatiques des comptes nécessaires**

Lorsqu’un nouvel employé rejoint l’entreprise, HelloID crée automatiquement un compte utilisateur dans Salto Space, permettant ainsi au collaborateur de commencer immédiatement son travail. En cas de modification des données d’un employé dans le système source, HelloID met également à jour les informations du compte dans Salto Space. Ces mises à jour s’intègrent automatiquement dans le cycle de vie des comptes utilisateurs géré par HelloID.

**Attribution ou suppression des groupes d’accès dans Salto Space**

Sur la base des données sources, HelloID peut attribuer un utilisateur à un groupe d’accès (limité ou non), ou bien lui retirer cet accès. Cela garantit que les droits d’accès sont toujours à jour.

Les comptes utilisateurs dans Salto Space incluent plusieurs champs personnalisables. HelloID peut mapper les données issues de vos systèmes sources vers ces champs, selon vos besoins.

## Avantages d’HelloID pour Salto Space

**Création accélérée des comptes :** En connectant Salto Space à vos systèmes sources, HelloID crée automatiquement des comptes utilisateurs basés sur les données disponibles. Cela garantit qu’un nouvel employé dispose immédiatement des droits d’accès physique aux espaces requis dès son premier jour de travail.

**Gestion des comptes sans erreur :** Grâce à cette intégration, HelloID applique des processus standardisés pour la gestion des comptes. Vous conservez le contrôle total tout en respectant les normes de conformité en vigueur. L’approche automatisée élimine les erreurs humaines. Ce point est crucial, car des droits d’accès mal configurés peuvent entraîner des problèmes. Si un employé ne peut pas accéder à un espace essentiel, sa productivité en souffre. À l’inverse, des droits excessifs peuvent compromettre la sécurité physique de vos locaux.

**Amélioration du service et renforcement de la sécurité :** En synchronisant vos systèmes sources avec Salto Space, vous améliorez à la fois votre niveau de service et votre sécurité. Les employés disposent toujours des accès appropriés au bon moment, réduisant ainsi les frustrations et augmentant leur satisfaction. Parallèlement, la sécurité de vos locaux est renforcée, car les employés ne conservent jamais des droits d’accès inutiles. En cas de perte ou de vol d’un smartphone ou d’une carte d’accès, l’impact potentiel est limité. 

## Intégration de Salto Space avec vos systèmes via HelloID

Avec HelloID, vous pouvez intégrer divers systèmes sources à Salto Space, améliorant ainsi la gestion des comptes utilisateurs et des accès physiques à vos locaux. Voici quelques exemples d'intégrations courantes : 

**Intégration ADP, CPAGE, LUCCAS, SAP, PLEIADES, ANTIBIA, CIRILL, etc.  - Salto Space :**

L'intégration entre ces différents systèmes RH et Salto Space renforce la collaboration entre vos services RH et IT. Grâce à cette connexion, HelloID peut, lors de l’embauche d’un nouvel employé, créer automatiquement un utilisateur dans Salto Space et l’associer au groupe d’accès approprié, y compris les groupes limités. Cela garantit un processus de provisioning des comptes fluide et efficace.


HelloID prend en charge plus de 200 connecteurs différents. Cette solution de GIA propose ainsi un large éventail de possibilités d'intégration entre vos systèmes sources et Salto Space. Notre portefeuille de connecteurs et d'intégrations est en constante évolution et s'élargit continuellement. Vous pouvez donc connecter HelloID à quasiment tous les systèmes populaires.

Curieux de découvrir les possibilités ? Consultez <a href="https://www.tools4ever.fr/connecteurs/">ici</a> un aperçu de tous les connecteurs disponibles.

