```markdown
# MonEA5 - Expert Advisor pour MetaTrader 5

## Description
MonEA5 est un Expert Advisor (EA) avancé pour MetaTrader 5, implémentant une stratégie de **Breakout de Range sur la Session Asiatique**. L'EA identifie des phases de consolidation pendant la session asiatique (0h-6h GMT) et place des ordres en attente pour capturer les mouvements directionnels lors de l'ouverture des marchés européens.

**Stratégie clé** : Range Breakout avec confirmation multi-filtres (volume, tendance, volatilité) et gestion des risques stricte, conçue pour être compatible avec les exigences des prop firms (ex: FundedNext).

## Prérequis
- **Plateforme** : MetaTrader 5 (version récente recommandée)
- **Compte** : Compte de trading avec accès au marché Forex (CFD)
- **Broker** : Doit fournir les données de volume réel (`SYMBOL_TRADE_TICK_VALUE`) si le filtre volume est activé.
- **Indicateur Externe** : L'EA utilise l'indicateur `FFCal.ex5` (Forex Factory Calendar) pour le filtre d'actualités. Assurez-vous qu'il est installé dans le dossier `MQL5\Indicators\`.

## Installation
1.  Téléchargez les fichiers de l'EA (`MonEA5.ex5` et `MonEA5.mq5` si disponible).
2.  Ouvrez le dossier de données de MetaTrader 5 (`Fichier > Ouvrir le dossier de données`).
3.  Naviguez vers `MQL5\Experts\`.
4.  Copiez le fichier `MonEA5.ex5` dans ce dossier.
5.  Redémarrez MetaTrader 5 ou actualisez la fenêtre "Navigateur" (Ctrl+N).
6.  L'EA `MonEA5` devrait maintenant apparaître dans la section "Experts Advisors" du Navigateur.

## Paramètres Configurables

### 1. Paramètres du Breakout (Cassure)
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `BreakoutType` | 0 | Type de cassure: `0=Range (High/Low)`, 1=BollingerBands, 2=ATR. |
| `AllowLong` | true | Autoriser les positions d'achat (Long). |
| `AllowShort` | true | Autoriser les positions de vente (Short). |
| `RequireVolumeConfirm` | true | Exiger une confirmation du volume pour valider un breakout. |
| `RequireRetest` | false | Attendre un retest du niveau cassé avant d'entrer (non utilisé). |
| `RangeTF` | PERIOD_D1 | Timeframe pour le calcul du range de prix. |
| `TrendFilterEMA` | 200 | Période de l'EMA utilisé comme filtre de tendance globale (0 pour désactiver). |
| `ExecTF` | PERIOD_M15 | Timeframe pour l'exécution des ordres et la surveillance. |

### 2. Filtre d'Actualités Économiques
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `UseNewsFilter` | true | Activer/désactiver le filtre d'actualités. |
| `NewsMinutesBefore` | 60 | Suspendre le trading X minutes AVANT l'annonce. |
| `NewsMinutesAfter` | 30 | Suspendre le trading X minutes APRÈS l'annonce. |
| `NewsImpactLevel` | 3 | Niveau d'impact minimum à filtrer: `1=Faible`, 2=Moyen, `3=Fort`. |
| `CloseOnHighImpact` | true | Fermer automatiquement les positions ouvertes avant une news d'impact Fort. |

### 3. Filtres Indicateurs
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `UseATRFilter` | true | Activer le filtre de volatilité ATR. |
| `ATRPeriod` | 14 | Période de calcul de l'ATR. |
| `MinATRPips` | 20 | Volatilité ATR minimum requise (en pips). |
| `MaxATRPips` | 150 | Volatilité ATR maximum autorisée (en pips). |
| `ATR_Mult_Min` | 1.25 | Le mouvement de cassure doit être > ATR * ce multiplicateur. |
| `UseBBFilter` | true | Activer le filtre de largeur de range via Bollinger Bands. |
| `Min_Width_Pips` | 30 | Largeur minimum des Bandes (en pips) pour valider un range. |
| `Max_Width_Pips` | 120 | Largeur maximum des Bandes (en pips) pour valider un range. |
| `UseEMAFilter` | true | Activer le filtre de tendance EMA. Strict: Achat si prix > EMA, Vente si prix < EMA. |
| `EMATf` | PERIOD_H1 | Timeframe pour le calcul de l'EMA de tendance. |
| `UseADXFilter` | true | Activer le filtre de force de tendance ADX. |
| `ADXThreshold` | 20.0 | Valeur ADX minimum pour considérer une tendance. |
| `UseVolumeFilter` | true | Activer le filtre de confirmation par volume. |
| `VolumeMultiplier` | 1.5 | Le volume actuel doit être > Moyenne(Volume) * ce multiplicateur. |

### 4. Gestion des Positions et des Risques
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `MagicNumber` | 123456 | Identifiant unique pour les ordres de cet EA. |
| `LotMethod` | 0 | Méthode de calcul des lots: `0=% du capital`, 1=Lot fixe, 2=Lot/pip. |
| `RiskPercent` | 1.0 | Pourcentage du capital à risquer par trade (si LotMethod=0). |
| `StopLossPips` | 0 | Stop Loss fixe en pips. `0` = SL placé au niveau opposé du range (Low pour un Buy, High pour un Sell). |
| `TakeProfitPips` | 0 | Take Profit fixe en pips. `0` = TP dynamique basé sur ATR. |
| `ATR_TP_Mult` | 3 | Multiplicateur ATR pour le TP dynamique (ex: ATR*3). |
| `MaxDailyDDPercent` | 5.0 | Drawdown quotidien maximum (%) avant arrêt du trading. |
| `MaxTotalDDPercent` | 10.0 | Drawdown total maximum (%) avant arrêt du trading. |
| `MaxOpenTrades` | 1 | Nombre maximum de positions simultanées (1 recommandé). |
| `MaxTradesPerDay` | 3 | Nombre maximum de trades ouverts par jour. |

### 5. Paramètres du Range et du Timing
| Paramètre | Valeur par défaut | Description |
| :--- | :--- | :--- |
| `RangePeriodHours` | 6 | Durée de la fenêtre pour calculer le range (session Asie: 0h-6h GMT). |
| `MarginPips` | 5 | Marge de sécurité ajoutée au-delà du High/Low pour placer les ordres en attente. |
| `TradeStartHour` | 8 | Heure GMT à partir de laquelle les ordres en attente peuvent être placés (ouverture London). |
| `WeekendClose` | true | Fermer toutes les positions avant le week-end. |
| `FridayCloseHour` | 21 | Heure GMT de fermeture forcée le vendredi. |

## Utilisation
1.  **Attacher l'EA** : Glissez-déposez `MonEA5` depuis le Navigateur sur un graphique (paire majeure recommandée, ex: EURUSD).
2.  **Timeframe** : L'EA fonctionne sur n'importe quel graphique, mais elle utilise en interne le D1 pour le range et le H1/M15 pour les filtres. Un graphique M15 ou M30 est conseillé pour la surveillance.
3.  **Activer le Trading Automatique** : Assurez-vous que le bouton "Auto Trading" (CTRL+E) est vert dans MT5.
4.  **Configurer les Paramètres** : Ajustez les paramètres d'entrée selon votre capital et votre profil de risque. Les valeurs par défaut sont un point de départ.
5.  **Démarrer** : L'EA calculera automatiquement le range de la session asiatique passée, placera des ordres en attente après 8h GMT et gérera les trades selon les règles définies.

**Fonctionnement Typique** :
- **Nuit (0h-6h GMT)** : L'EA calcule le High et le Low de la session asiatique.
- **Matin (après 8h GMT)** : Place des ordres `Buy Stop` (au High + Marge) et `Sell Stop` (au Low - Marge).
- **Breakout** : Si le prix casse un niveau avec confirmation (volume, ATR), l'ordre correspondant est déclenché.
- **Gestion** : Le Stop Loss est placé de l'autre côté du range. Le Take Profit est calculé dynamiquement (ATR). Le trailing stop peut s'activer.

## Avertissement sur les Risques
**LE TRADING SUR MARCHÉS FINANCIERS IMPLIQUE DES RISQUES ÉLEVÉS DE PERTE.** Cet Expert Advisor est un outil logiciel fourni "tel quel", à des fins éducatives et de recherche. Son passé ne préjuge en rien de ses performances futures.

- **Testez rigoureusement** l'EA en backtest et sur un compte de démonstration avant toute utilisation réelle.
- **Comprenez parfaitement** la stratégie et tous les paramètres de gestion des risques.
- **Ne risquez jamais** de capital dont vous ne pouvez pas vous passer.
- **Surveillez activement** l'EA, surtout lors de publications économiques majeures ou de conditions de marché anormales.
- L'auteur/éditeur décline toute responsabilité concernant les pertes financières ou les dommages résultant de l'utilisation de ce logiciel.

Il est de votre responsabilité de vous assurer que l'utilisation d'un EA automatisé est conforme aux conditions de votre broker et aux réglementations de votre pays de résidence.
```