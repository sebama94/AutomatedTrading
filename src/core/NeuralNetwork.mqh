//+------------------------------------------------------------------+
//| NeuralNetwork.mqh                                                |
//| Rete neurale feed-forward con:                                   |
//|   - Ottimizzatore Adam (vs SGD vanilla)                          |
//|   - Regolarizzazione L2                                          |
//|   - Gradient clipping                                            |
//|   - Early stopping con validazione                               |
//|   - Inizializzazione He simmetrica                               |
//+------------------------------------------------------------------+
#pragma once

#define NN_MAX_LAYERS 12

class NeuralNetwork
{
private:
   int    m_numLayers;
   int    m_layerSizes[];
   double m_neurons[];
   double m_weights[];
   double m_biases[];

   // Adam optimizer state
   double m_w_m[];      // first moment weights
   double m_w_v[];      // second moment weights
   double m_b_m[];      // first moment biases
   double m_b_v[];      // second moment biases
   int    m_t;          // timestep

   // Iperparametri
   double m_lr;
   double m_beta1;
   double m_beta2;
   double m_epsilon;
   double m_l2;
   double m_clipNorm;

public:
   NeuralNetwork(double lr       = 0.001,
                 double beta1    = 0.9,
                 double beta2    = 0.999,
                 double epsilon  = 1e-8,
                 double l2       = 1e-5,
                 double clipNorm = 1.0);
   ~NeuralNetwork() {}

   bool   BuildModel(int &layerSizes[], int numLayers);
   void   FeedForward(double &inputs[]);
   void   GetOutputs(double &outputs[]);
   void   Train(double &inputs[], double &targets[], int epochs, int patience = 50);
   double EvaluateLoss(double &inputs[], double &targets[]);

private:
   bool   Initialize(int &layerSizes[], int numLayers);
   void   BackPropagate(double &inputs[], double &targets[]);
   double Relu(double x)            { return MathMax(0.0, x); }
   double ReluDeriv(double x)       { return x > 0.0 ? 1.0 : 0.0; }
   double Sigmoid(double x)         { return 1.0 / (1.0 + MathExp(-x)); }
   double CrossEntropy(double &t[], double &o[]);
   bool   CheckInputRange(const double &v[]);
   void   ShuffleRange(int &idx[], int n);
};

//--- Constructor
NeuralNetwork::NeuralNetwork(double lr, double beta1, double beta2,
                              double epsilon, double l2, double clipNorm)
{
   m_numLayers = 0;
   m_lr        = lr;
   m_beta1     = beta1;
   m_beta2     = beta2;
   m_epsilon   = epsilon;
   m_l2        = l2;
   m_clipNorm  = clipNorm;
   m_t         = 0;
}

//--- Alloca memoria e inizializza pesi con He
bool NeuralNetwork::Initialize(int &layerSizes[], int numLayers)
{
   if(numLayers < 2 || numLayers > NN_MAX_LAYERS)
   {
      Print("NeuralNetwork: layer count fuori range (2-", NN_MAX_LAYERS, ")");
      return false;
   }

   m_numLayers = numLayers;
   ArrayResize(m_layerSizes, numLayers);

   int totalN = 0, totalW = 0, totalB = 0;
   for(int i = 0; i < numLayers; i++)
   {
      m_layerSizes[i] = layerSizes[i];
      totalN += layerSizes[i];
      if(i < numLayers - 1)
      {
         totalW += layerSizes[i] * layerSizes[i + 1];
         totalB += layerSizes[i + 1];
      }
   }

   ArrayResize(m_neurons, totalN); ArrayInitialize(m_neurons, 0);
   ArrayResize(m_weights, totalW); ArrayInitialize(m_weights, 0);
   ArrayResize(m_biases,  totalB); ArrayInitialize(m_biases,  0);

   // Adam state (zero init)
   ArrayResize(m_w_m, totalW); ArrayInitialize(m_w_m, 0);
   ArrayResize(m_w_v, totalW); ArrayInitialize(m_w_v, 0);
   ArrayResize(m_b_m, totalB); ArrayInitialize(m_b_m, 0);
   ArrayResize(m_b_v, totalB); ArrayInitialize(m_b_v, 0);
   m_t = 0;

   return true;
}

//--- Costruisce il modello con inizializzazione He simmetrica
bool NeuralNetwork::BuildModel(int &layerSizes[], int numLayers)
{
   if(!Initialize(layerSizes, numLayers)) return false;

   int wIdx = 0;
   for(int layer = 0; layer < numLayers - 1; layer++)
   {
      int fanIn  = layerSizes[layer];
      int fanOut = layerSizes[layer + 1];
      double scale = MathSqrt(2.0 / fanIn); // He init

      for(int i = 0; i < fanOut; i++)
         for(int j = 0; j < fanIn; j++)
         {
            // Segno casuale × He scale per simmetria (Box-Muller approssimato)
            double u1 = (MathRand() + 1.0) / 32769.0;
            double u2 = (MathRand() + 1.0) / 32769.0;
            double z  = MathSqrt(-2.0 * MathLog(u1)) * MathCos(2.0 * M_PI * u2);
            m_weights[wIdx++] = z * scale;
         }
   }
   return true;
}

//--- Forward pass
void NeuralNetwork::FeedForward(double &inputs[])
{
   if(ArraySize(inputs) < m_layerSizes[0])
   {
      Print("FeedForward: input troppo piccolo");
      return;
   }

   int nIdx = 0, wIdx = 0, bIdx = 0;

   for(int i = 0; i < m_layerSizes[0]; i++)
      m_neurons[nIdx++] = MathMax(-1.0, MathMin(1.0, inputs[i])); // soft clamp

   for(int layer = 1; layer < m_numLayers; layer++)
   {
      int prevSize = m_layerSizes[layer - 1];
      int currSize = m_layerSizes[layer];
      bool isOutput = (layer == m_numLayers - 1);

      for(int i = 0; i < currSize; i++)
      {
         double sum = m_biases[bIdx + i];
         for(int j = 0; j < prevSize; j++)
            sum += m_neurons[nIdx - prevSize + j] * m_weights[wIdx + i * prevSize + j];

         m_neurons[nIdx + i] = isOutput ? Sigmoid(sum) : Relu(sum);
      }
      nIdx += currSize;
      wIdx += prevSize * currSize;
      bIdx += currSize;
   }
}

//--- Legge il layer di output
void NeuralNetwork::GetOutputs(double &outputs[])
{
   int outSize  = m_layerSizes[m_numLayers - 1];
   int outStart = ArraySize(m_neurons) - outSize;
   ArrayResize(outputs, outSize);
   for(int i = 0; i < outSize; i++)
      outputs[i] = m_neurons[outStart + i];
}

//--- Backpropagation con raccolta gradienti + clipping + Adam
void NeuralNetwork::BackPropagate(double &inputs[], double &targets[])
{
   FeedForward(inputs);

   int    outLayer = m_numLayers - 1;
   int    outSize  = m_layerSizes[outLayer];
   double errors[];
   ArrayResize(errors, ArraySize(m_neurons));
   ArrayInitialize(errors, 0.0);

   double wGrads[], bGrads[];
   ArrayResize(wGrads, ArraySize(m_weights));
   ArrayResize(bGrads, ArraySize(m_biases));
   ArrayInitialize(wGrads, 0.0);
   ArrayInitialize(bGrads, 0.0);

   int nIdx = ArraySize(m_neurons) - outSize;
   int wIdx = ArraySize(m_weights) - outSize * m_layerSizes[outLayer - 1];
   int bIdx = ArraySize(m_biases)  - outSize;

   // Errori output (sigmoid derivative inclusa)
   for(int i = 0; i < outSize; i++)
   {
      double o = m_neurons[nIdx + i];
      errors[nIdx + i] = (o - targets[i]) * o * (1.0 - o);
   }

   // Raccoglie gradienti strato per strato (backprop)
   for(int layer = outLayer; layer > 0; layer--)
   {
      int currSize = m_layerSizes[layer];
      int prevSize = m_layerSizes[layer - 1];

      for(int i = 0; i < currSize; i++)
      {
         bGrads[bIdx + i] = errors[nIdx + i];
         for(int j = 0; j < prevSize; j++)
            wGrads[wIdx + i * prevSize + j] = errors[nIdx + i] * m_neurons[nIdx - prevSize + j];
      }

      if(layer > 1)
      {
         int pNIdx = nIdx - prevSize;
         int pWIdx = wIdx - prevSize * m_layerSizes[layer - 2];
         for(int j = 0; j < prevSize; j++)
         {
            double e = 0;
            for(int i = 0; i < currSize; i++)
               e += errors[nIdx + i] * m_weights[wIdx + i * prevSize + j];
            errors[pNIdx + j] = e * ReluDeriv(m_neurons[pNIdx + j]);
         }
         nIdx = pNIdx;
         wIdx = pWIdx;
         bIdx -= prevSize;
      }
   }

   // Gradient clipping (global norm)
   if(m_clipNorm > 0)
   {
      double norm2 = 0;
      int wSz = ArraySize(wGrads), bSz = ArraySize(bGrads);
      for(int i = 0; i < wSz; i++) norm2 += wGrads[i] * wGrads[i];
      for(int i = 0; i < bSz; i++) norm2 += bGrads[i] * bGrads[i];
      double norm = MathSqrt(norm2);
      if(norm > m_clipNorm)
      {
         double s = m_clipNorm / norm;
         for(int i = 0; i < wSz; i++) wGrads[i] *= s;
         for(int i = 0; i < bSz; i++) bGrads[i] *= s;
      }
   }

   // Adam update
   m_t++;
   double bc1 = 1.0 - MathPow(m_beta1, (double)m_t);
   double bc2 = 1.0 - MathPow(m_beta2, (double)m_t);

   for(int i = 0; i < ArraySize(m_weights); i++)
   {
      double g = wGrads[i] + m_l2 * m_weights[i]; // L2 reg
      m_w_m[i] = m_beta1 * m_w_m[i] + (1.0 - m_beta1) * g;
      m_w_v[i] = m_beta2 * m_w_v[i] + (1.0 - m_beta2) * g * g;
      m_weights[i] -= m_lr * (m_w_m[i] / bc1) / (MathSqrt(m_w_v[i] / bc2) + m_epsilon);
   }
   for(int i = 0; i < ArraySize(m_biases); i++)
   {
      double g = bGrads[i];
      m_b_m[i] = m_beta1 * m_b_m[i] + (1.0 - m_beta1) * g;
      m_b_v[i] = m_beta2 * m_b_v[i] + (1.0 - m_beta2) * g * g;
      m_biases[i] -= m_lr * (m_b_m[i] / bc1) / (MathSqrt(m_b_v[i] / bc2) + m_epsilon);
   }
}

//--- Training completo con split train/val e early stopping
void NeuralNetwork::Train(double &inputs[], double &targets[], int epochs, int patience = 50)
{
   int inSz  = m_layerSizes[0];
   int outSz = m_layerSizes[m_numLayers - 1];
   int N     = ArraySize(inputs) / inSz;

   if(N != ArraySize(targets) / outSz)
   {
      Print("Train: mismatch campioni input/target");
      return;
   }

   int trainN = (int)(N * 0.8);
   int valN   = N - trainN;
   if(valN < 1) { Print("Train: dataset troppo piccolo per validazione"); return; }

   Print("Training: N=", N, " train=", trainN, " val=", valN, " epochs=", epochs, " patience=", patience);

   int indices[];
   ArrayResize(indices, N);
   for(int i = 0; i < N; i++) indices[i] = i;
   ShuffleRange(indices, N); // split iniziale casuale

   double bestValLoss = 1e18;
   int    noImprov    = 0;
   double savedW[], savedB[];
   ArrayCopy(savedW, m_weights);
   ArrayCopy(savedB, m_biases);

   double sIn[], sTgt[], sOut[];
   ArrayResize(sIn,  inSz);
   ArrayResize(sTgt, outSz);

   for(int epoch = 0; epoch < epochs; epoch++)
   {
      ShuffleRange(indices, trainN); // shuffle solo la porzione training

      // Training pass
      for(int s = 0; s < trainN; s++)
      {
         int idx = indices[s];
         for(int j = 0; j < inSz;  j++) sIn[j]  = inputs[ idx * inSz  + j];
         for(int j = 0; j < outSz; j++) sTgt[j]  = targets[idx * outSz + j];
         BackPropagate(sIn, sTgt);
      }

      // Validation pass
      double valLoss = 0;
      for(int s = trainN; s < N; s++)
      {
         int idx = indices[s];
         for(int j = 0; j < inSz;  j++) sIn[j]  = inputs[ idx * inSz  + j];
         for(int j = 0; j < outSz; j++) sTgt[j]  = targets[idx * outSz + j];
         FeedForward(sIn);
         GetOutputs(sOut);
         valLoss += CrossEntropy(sTgt, sOut);
      }
      valLoss /= valN;

      if((epoch + 1) % 50 == 0 || epoch == 0)
         Print("Epoch ", epoch + 1, "/", epochs, "  val_loss=", DoubleToString(valLoss, 6));

      if(valLoss < bestValLoss - 1e-7)
      {
         bestValLoss = valLoss;
         noImprov    = 0;
         ArrayCopy(savedW, m_weights);
         ArrayCopy(savedB, m_biases);
      }
      else if(++noImprov >= patience)
      {
         Print("Early stop ep.", epoch + 1, "  best_val=", DoubleToString(bestValLoss, 6));
         break;
      }
   }

   ArrayCopy(m_weights, savedW);
   ArrayCopy(m_biases,  savedB);
   Print("Training completato. Best val loss: ", DoubleToString(bestValLoss, 6));
}

//--- Loss su tutto il dataset (per monitoring)
double NeuralNetwork::EvaluateLoss(double &inputs[], double &targets[])
{
   int inSz  = m_layerSizes[0];
   int outSz = m_layerSizes[m_numLayers - 1];
   int N     = ArraySize(inputs) / inSz;
   double sIn[], sTgt[], sOut[], total = 0;
   ArrayResize(sIn,  inSz);
   ArrayResize(sTgt, outSz);
   for(int s = 0; s < N; s++)
   {
      for(int j = 0; j < inSz;  j++) sIn[j]  = inputs[ s * inSz  + j];
      for(int j = 0; j < outSz; j++) sTgt[j]  = targets[s * outSz + j];
      FeedForward(sIn);
      GetOutputs(sOut);
      total += CrossEntropy(sTgt, sOut);
   }
   return (N > 0) ? total / N : 0;
}

double NeuralNetwork::CrossEntropy(double &t[], double &o[])
{
   double s = 0, eps = 1e-15;
   int n = MathMin(ArraySize(t), ArraySize(o));
   for(int i = 0; i < n; i++)
      s += t[i] * MathLog(o[i] + eps) + (1.0 - t[i]) * MathLog(1.0 - o[i] + eps);
   return -s / n;
}

bool NeuralNetwork::CheckInputRange(const double &v[])
{
   for(int i = 0; i < ArraySize(v); i++)
      if(v[i] < -1.001 || v[i] > 1.001) return false;
   return true;
}

void NeuralNetwork::ShuffleRange(int &idx[], int n)
{
   for(int i = n - 1; i > 0; i--)
   {
      int j = (int)(MathRand() / 32768.0 * (i + 1));
      if(j >= n) j = n - 1;
      int tmp = idx[i]; idx[i] = idx[j]; idx[j] = tmp;
   }
}
