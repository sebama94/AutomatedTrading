# ML Trading System v4.0

Sistema di trading algoritmico basato su ensemble di reti neurali per MetaTrader 5.

---

## Architettura

```
main.mq5
└── src/
    ├── MLTrader.mqh              Orchestratore — ensemble, walk-forward, regime, Kelly
    ├── core/
    │   └── NeuralNetwork.mqh     NN con Adam, L2, clipping, early stopping
    ├── features/
    │   └── FeatureEngine.mqh     80 feature da M30 + H1 + H4 + tempo + global
    ├── risk/
    │   └── RiskManager.mqh       ATR sizing, Kelly Criterion, circuit breaker, daily loss
    ├── execution/
    │   └── OrderManager.mqh      Spread/sessione filter, trailing stop ATR
    └── regime/
        └── RegimeDetector.mqh    ADX + ATR ratio → TREND / RANGE / VOLATILE

Backtest.mq5                      Report post-backtest: Win Rate, PF, Sharpe, Calmar
legacy/                           Versioni precedenti (v1, v2)
```

---

## Migliorie v4 (7 improvements)

| # | Miglioria | Descrizione |
|---|-----------|-------------|
| 1 | **Label profittabilità** | Scan forward N barre: BUY vince se High≥TP prima che Low≤SL. Elimina il 50/50 delle label direzionali. |
| 2 | **Ensemble 3 modelli** | Tre NN identiche allegate su finestre storiche diverse (recente/media/vecchia). Pesi [0.5, 0.3, 0.2]. |
| 3 | **Walk-forward retraining** | Ogni `InpRetrainEveryBars` barre M30 l'ensemble viene riaddestrato sui dati più recenti. |
| 4 | **RegimeDetector** | ADX(14,H1) + ratio ATR(5)/ATR(50) → TREND/RANGE/VOLATILE. Nessun trade in VOLATILE. |
| 5 | **Kelly Criterion** | Half-Kelly: `f* = (p·b − q)/b × 0.5`. Lotto scalato per confidenza della rete, capped a 3× rischio base. |
| 6 | **80 feature avanzate** | +4 global features: vol expansion, momentum 10-bar, MACD alignment M30/H1 e M30/H4. |
| 7 | **Backtest.mq5** | EA per Strategy Tester: calcola Win Rate, Profit Factor, Max DD, Sharpe, Calmar, Expectancy. |

---

## Pipeline

### Training (OnInit)
1. Per ogni modello dell'ensemble (×3): raccoglie ~666 barre su finestra storica diversa
2. Label: scan forward fino a `InpMaxForwardBars` barre → BUY/SELL = raggiunge TP prima di SL
3. Allena NN `80→128→64→32→2` con Adam + early stopping (20% validation)

### Inferenza (ogni nuova barra M30)
1. Controllo walk-forward: se `barsSinceRetrain ≥ InpRetrainEveryBars` → riallena
2. Regime check: `VOLATILE` → skip
3. Estrae 80 feature correnti
4. Ensemble forward pass → `probBuy`, `probSell` (media pesata)
5. Se `prob > 0.65` e filtri OK → Kelly sizing → ordine

---

## Feature (80 totali)

| Gruppo | Barre | Features | Indici |
|--------|-------|----------|--------|
| M30 | 5 | 8/barra | 0–39 |
| H1 | 3 | 8/barra | 40–63 |
| H4 | 1 | 8/barra | 64–71 |
| Tempo | — | 4 ciclici | 72–75 |
| Global | — | 4 global | 76–79 |

**8 feature per barra:** MACD/ATR, RSI, Stochastic %K, ADX, Bollinger %B, ATR%, Return, EMA50 dev

**4 feature temporali:** sin/cos ora, sin/cos giorno settimana

**4 feature globali:**
- `[76]` Vol expansion: ATR(14)/ATR(100) − 1
- `[77]` Momentum 10-bar: (close − close[10]) / (ATR × 10)
- `[78]` Allineamento MACD M30/H1: +1 concordanti, −1 discordanti
- `[79]` Allineamento MACD M30/H4: +1 concordanti, −1 discordanti

---

## Rete Neurale

| Parametro | Valore |
|-----------|--------|
| Architettura | 80→128→64→32→2 |
| Ottimizzatore | Adam (β1=0.9, β2=0.999, ε=1e-8) |
| Regularizzazione | L2 (λ=1e-5) |
| Gradient clipping | global norm ≤ 1.0 |
| Attivazione hidden | ReLU |
| Attivazione output | Sigmoid |
| Inizializzazione | He (Box-Muller) |
| Validation split | 20% |
| Early stopping | patience=50 epoche |

---

## Regime Detection

| Condizione | Regime | Azione |
|------------|--------|--------|
| ATR_fast/ATR_slow > 1.5 | VOLATILE | No trade |
| ATR ratio < 0.67 | VOLATILE | No trade |
| ADX(14,H1) > 25 | TREND | Trade direzionale |
| ADX < 20 | RANGE | Trade (mean-reversion favorita) |
| 20 ≤ ADX ≤ 25 | TREND debole | Trade (trattato come trend) |

---

## Kelly Criterion

```
f* = (p × b − q) / b   dove p=probWin, q=1-p, b=R:R ratio
kelly_used = f* × 0.5  (half-Kelly per safety)
kelly_used = min(kelly_used, 3 × baseRisk)  (ceiling)
```

Se Kelly < 0 (edge negativo) → lotto = 0, nessun ordine aperto.

---

## Risk Management

| Parametro | Default | Descrizione |
|-----------|---------|-------------|
| `InpRiskPerTrade` | 1% | Rischio base (usato come floor per Kelly) |
| `InpMaxDailyLoss` | 3% | Stop trading se perdita giornaliera > 3% |
| `InpMaxDrawdown` | 10% | Circuit breaker attivo su drawdown > 10% |
| SL | ATR(14,H1) × `InpSLAtrMult` | Stop loss dinamico |
| TP | SL × (`InpTPAtrMult`/`InpSLAtrMult`) | R:R configurabile |

---

## Filtri Esecuzione

- **Sessione**: London (07–16 GMT) + New York (13–21 GMT) — Asian esclusa
- **Spread**: max `InpMaxSpreadPips` pips
- **Trailing stop**: ATR(14,H1) × 1.5, solo oltre break-even
- **Posizioni**: max `InpMaxPositions` simultanee
- **Timeout**: nessun trade nella stessa direzione per `InpTimeoutMinutes` minuti

---

## Parametri Configurabili (main.mq5)

| Input | Default | Descrizione |
|-------|---------|-------------|
| `InpSymbol` | EURUSD | Simbolo |
| `InpMagic` | 20240001 | Magic number EA |
| `InpEpochs` | 500 | Epoche per modello |
| `InpTrainSamples` | 2000 | Campioni totali (÷3 per modello) |
| `InpLearningRate` | 0.001 | Adam LR |
| `InpEarlyStopping` | 50 | Patience early stopping |
| `InpSLAtrMult` | 1.0 | Mult. ATR Stop Loss |
| `InpTPAtrMult` | 2.0 | Mult. ATR Take Profit |
| `InpMaxForwardBars` | 20 | Barre forward per label scan |
| `InpRetrainEveryBars` | 500 | Barre tra retrain walk-forward |
| `InpRiskPerTrade` | 0.01 | Rischio base per trade |
| `InpMaxDailyLoss` | 0.03 | Perdita max giornaliera |
| `InpMaxDrawdown` | 0.10 | Drawdown max circuit breaker |
| `InpMaxSpreadPips` | 2.0 | Spread massimo |
| `InpCloseProfitUSD` | 10.0 | Chiusura a profitto ($) |
| `InpMaxPositions` | 3 | Posizioni aperte massime |
| `InpTimeoutMinutes` | 30 | Timeout tra segnali per direzione |

---

## File Legacy

La cartella `legacy/` contiene le versioni precedenti (v1 e v2) per riferimento.
