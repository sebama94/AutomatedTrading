# ML Trading System v3.0

Sistema di trading algoritmico basato su reti neurali per MetaTrader 5.

---

## Architettura

```
main.mq5
└── src/
    ├── MLTrader.mqh              Orchestratore principale
    ├── core/
    │   └── NeuralNetwork.mqh     NN con Adam, L2, clipping, early stopping
    ├── features/
    │   └── FeatureEngine.mqh     76 feature da M30 + H1 + H4 + tempo
    ├── risk/
    │   └── RiskManager.mqh       ATR sizing, circuit breaker, daily loss
    └── execution/
        └── OrderManager.mqh      Spread/sessione filter, trailing stop ATR
```

---

## Pipeline

### Training (OnInit)
1. Raccoglie `InpTrainSamples` barre storiche M30
2. Estrae 76 feature per barra da 3 timeframe (M30, H1, H4)
3. Genera label **forward-looking**: direzione della barra successiva
4. Allena NN `76→128→64→32→2` con Adam + early stopping su validation set (20%)

### Inferenza (ogni nuova barra M30)
1. Estrae feature correnti
2. Forward pass → `probBuy`, `probSell` ∈ [0,1]
3. Apre ordine solo se `prob > 0.65` e filtri OK (spread, sessione, rischio)
4. Stop Loss calcolato su ATR × 2.0, Take Profit a R:R 1:2

---

## Feature (76 totali)

| Gruppo | Barre | Features | Indici |
|--------|-------|----------|--------|
| M30 | 5 | 8/barra | 0–39 |
| H1 | 3 | 8/barra | 40–63 |
| H4 | 1 | 8/barra | 64–71 |
| Tempo | — | 4 ciclici | 72–75 |

**8 feature per barra:**
- MACD histogram / ATR
- RSI normalizzato [-1,1]
- Stochastic %K [-1,1]
- ADX [-1,1]
- Bollinger %B [-1,1]
- ATR% (volatilità relativa, soft-clipped)
- Return barra (soft-clipped)
- Deviazione EMA50 / ATR (soft-clipped)

**4 feature temporali** (codifica ciclica):
- sin/cos ora del giorno
- sin/cos giorno della settimana

---

## Rete Neurale (src/core/NeuralNetwork.mqh)

| Parametro | Valore |
|-----------|--------|
| Architettura | 76→128→64→32→2 |
| Ottimizzatore | **Adam** (β1=0.9, β2=0.999, ε=1e-8) |
| Regularizzazione | **L2** (λ=1e-5) |
| Gradient clipping | global norm ≤ 1.0 |
| Attivazione hidden | **ReLU** |
| Attivazione output | **Sigmoid** |
| Inizializzazione | **He** (simmetrica, Box-Muller) |
| Validation split | 20% del dataset |
| Early stopping | patience=50 epoche su val loss |

---

## Risk Management (src/risk/RiskManager.mqh)

| Parametro | Default | Descrizione |
|-----------|---------|-------------|
| `InpRiskPerTrade` | 1% | Capitale rischiato per trade (ATR-based sizing) |
| `InpMaxDailyLoss` | 3% | Stop trading se perdita giornaliera > 3% |
| `InpMaxDrawdown` | 10% | Circuit breaker attivo su drawdown > 10% |
| SL | ATR(14, H1) × 2 | Stop loss dinamico adattivo |
| TP | SL distance × 2 | R:R fisso 1:2 |

---

## Filtri Esecuzione (src/execution/OrderManager.mqh)

- **Sessione**: London (07–16 GMT) + New York (13–21 GMT) — Asian esclusa
- **Spread**: max 2 pips (configurabile)
- **Trailing stop**: ATR(14, H1) × 1.5, solo in direzione favorevole oltre break-even
- **Posizioni**: max 3 simultanee per simbolo

---

## Parametri Configurabili (main.mq5)

| Input | Default | Descrizione |
|-------|---------|-------------|
| `InpSymbol` | EURUSD | Simbolo di trading |
| `InpMagic` | 20240001 | Magic number EA |
| `InpEpochs` | 500 | Epoche di training |
| `InpTrainSamples` | 2000 | Campioni training storici |
| `InpLearningRate` | 0.001 | Adam learning rate |
| `InpEarlyStopping` | 50 | Patience early stopping |
| `InpRiskPerTrade` | 0.01 | Rischio per trade (frazione balance) |
| `InpMaxDailyLoss` | 0.03 | Perdita max giornaliera |
| `InpMaxDrawdown` | 0.10 | Drawdown max (circuit breaker) |
| `InpMaxSpreadPips` | 2.0 | Spread massimo accettato |
| `InpCloseProfitUSD` | 10.0 | Chiusura posizione a profitto ($) |
| `InpMaxPositions` | 3 | Posizioni aperte massime |
| `InpTimeoutMinutes` | 30 | Timeout tra segnali per direzione |

---

## File Legacy

La cartella `legacy/` contiene le versioni precedenti (v1 e v2) per riferimento.
