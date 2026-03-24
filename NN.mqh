//+------------------------------------------------------------------+
//|                                                           NN.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include <Arrays\ArrayString.mqh>

#define MAX_LAYERS   10
#define MAX_NEURONS  100000

class NeuralNetwork
{
private:
   int    m_numLayers;
   int    m_layerSizes[];
   double m_neurons[];
   double m_weights[];
   double m_biases[];
   double m_learningRate;

public:
               NeuralNetwork(double learningRate = 0.01);
              ~NeuralNetwork();

   bool        Initialize(int &layerSizes[], int numLayers);
   void        SetWeights(double &weights[]);
   void        SetBiases(double &biases[]);
   void        FeedForward(double &inputs[]);
   void        GetOutputs(double &outputs[]);
   void        BuildModel(int &layerSizes[], int numLayers);
   void        Train(double &inputs[], double &targets[], int epochs, double learningRate);
   void        PrintWeights();

private:
   double      ActivateHidden(double x);
   double      ActivateHiddenDerivative(double x);
   void        BackPropagate(double &inputs[], double &targets[], double learningRate);
   double      CrossEntropyLoss(double &targets[], double &outputs[]);
   string      DoubleArrayToString(const double &arr[], int start = 0, int count = WHOLE_ARRAY);
   bool        AreInputsInRange(const double &inputs[]);
   bool        AreTargetsInRange(const double &targets[]);
};

NeuralNetwork::NeuralNetwork(double learningRate = 0.01)
{
   m_numLayers   = 0;
   m_learningRate = learningRate;
   ArrayInitialize(m_layerSizes, 0);
   ArrayResize(m_neurons, 0);
   ArrayResize(m_weights, 0);
   ArrayResize(m_biases,  0);
}

NeuralNetwork::~NeuralNetwork() {}

bool NeuralNetwork::Initialize(int &layerSizes[], int numLayers)
{
   if(numLayers > MAX_LAYERS)
   {
      Print("Errore: troppi layer (max ", MAX_LAYERS, ")");
      return false;
   }

   m_numLayers = numLayers;
   ArrayResize(m_layerSizes, m_numLayers);

   int totalNeurons = 0;
   for(int i = 0; i < numLayers; i++)
   {
      if(layerSizes[i] > MAX_NEURONS)
      {
         Print("Errore: layer ", i, " ha troppi neuroni (max ", MAX_NEURONS, ")");
         return false;
      }
      m_layerSizes[i] = layerSizes[i];
      totalNeurons += layerSizes[i];
   }

   ArrayResize(m_neurons, totalNeurons);
   ArrayInitialize(m_neurons, 0);

   int totalWeights = 0;
   int totalBiases  = 0;
   for(int i = 0; i < numLayers - 1; i++)
   {
      totalWeights += layerSizes[i] * layerSizes[i + 1];
      totalBiases  += layerSizes[i + 1];
   }

   ArrayResize(m_weights, totalWeights);
   ArrayInitialize(m_weights, 0);
   ArrayResize(m_biases, totalBiases);
   ArrayInitialize(m_biases, 0);

   return true;
}

void NeuralNetwork::SetWeights(double &weights[])
{
   if(ArraySize(weights) != ArraySize(m_weights))
   {
      Print("Errore: dimensione weights non corrisponde");
      return;
   }
   ArrayCopy(m_weights, weights);
}

void NeuralNetwork::SetBiases(double &biases[])
{
   if(ArraySize(biases) != ArraySize(m_biases))
   {
      Print("Errore: dimensione biases non corrisponde");
      return;
   }
   ArrayCopy(m_biases, biases);
}

void NeuralNetwork::FeedForward(double &inputs[])
{
   if(ArraySize(inputs) < m_layerSizes[0])
   {
      Print("Errore: input troppo piccolo (", ArraySize(inputs), " < ", m_layerSizes[0], ")");
      return;
   }
   if(!AreInputsInRange(inputs))
   {
      Print("Errore: input fuori range [-1, 1]");
      return;
   }

   int neuronIndex = 0;
   int weightIndex = 0;
   int biasIndex   = 0;

   for(int i = 0; i < m_layerSizes[0]; i++)
      m_neurons[neuronIndex++] = inputs[i];

   for(int layer = 1; layer < m_numLayers; layer++)
   {
      for(int i = 0; i < m_layerSizes[layer]; i++)
      {
         double sum = 0;
         for(int j = 0; j < m_layerSizes[layer - 1]; j++)
            sum += m_neurons[neuronIndex - m_layerSizes[layer - 1] + j] * m_weights[weightIndex++];
         sum += m_biases[biasIndex++];

         if(layer == m_numLayers - 1)
            m_neurons[neuronIndex++] = 1.0 / (1.0 + MathExp(-sum)); // Sigmoid output
         else
            m_neurons[neuronIndex++] = ActivateHidden(sum);           // ReLU hidden
      }
   }
}

void NeuralNetwork::GetOutputs(double &outputs[])
{
   int outputLayer = m_numLayers - 1;
   int outputStart = ArraySize(m_neurons) - m_layerSizes[outputLayer];

   if(ArrayResize(outputs, m_layerSizes[outputLayer]) != m_layerSizes[outputLayer])
   {
      Print("Errore: impossibile ridimensionare outputs");
      return;
   }
   for(int i = 0; i < m_layerSizes[outputLayer]; i++)
      outputs[i] = m_neurons[outputStart + i];
}

void NeuralNetwork::BuildModel(int &layerSizes[], int numLayers)
{
   if(!Initialize(layerSizes, numLayers))
   {
      Print("Errore: inizializzazione NN fallita");
      return;
   }

   double weights[];
   double biases[];
   ArrayResize(weights, ArraySize(m_weights));
   ArrayResize(biases,  ArraySize(m_biases));

   int weightIndex = 0;
   int biasIndex   = 0;

   for(int layer = 0; layer < numLayers - 1; layer++)
   {
      int fanIn  = layerSizes[layer];
      int fanOut = layerSizes[layer + 1];
      double scale = MathSqrt(2.0 / fanIn); // He initialization

      for(int i = 0; i < fanOut; i++)
      {
         for(int j = 0; j < fanIn; j++)
         {
            // Valori casuali in (-1, 1) * scale per He init con ReLU
            double rnd = (MathRand() / 16384.0 - 1.0) * scale;
            weights[weightIndex++] = rnd;
         }
         biases[biasIndex++] = 0.0;
      }
   }

   SetWeights(weights);
   SetBiases(biases);
}

double NeuralNetwork::ActivateHidden(double x)
{
   return MathMax(0.0, x); // ReLU
}

double NeuralNetwork::ActivateHiddenDerivative(double x)
{
   return x > 0.0 ? 1.0 : 0.0;
}

void NeuralNetwork::BackPropagate(double &inputs[], double &targets[], double learningRate)
{
   if(!AreInputsInRange(inputs))
   {
      Print("Errore backprop: input fuori range [-1, 1]");
      return;
   }
   if(!AreTargetsInRange(targets))
   {
      Print("Errore backprop: targets fuori range [0, 1]");
      return;
   }

   FeedForward(inputs);

   int    outputLayer = m_numLayers - 1;
   double errors[];
   ArrayResize(errors, ArraySize(m_neurons));
   ArrayInitialize(errors, 0.0);

   if(ArraySize(targets) < m_layerSizes[outputLayer])
   {
      Print("Errore: targets troppo piccolo");
      return;
   }

   int neuronIndex = ArraySize(m_neurons) - m_layerSizes[outputLayer];
   int weightIndex = ArraySize(m_weights) - m_layerSizes[outputLayer] * m_layerSizes[outputLayer - 1];
   int biasIndex   = ArraySize(m_biases)  - m_layerSizes[outputLayer];

   // Errori output layer (sigmoid derivative inclusa)
   for(int i = 0; i < m_layerSizes[outputLayer]; i++)
   {
      double out = m_neurons[neuronIndex + i];
      errors[neuronIndex + i] = (out - targets[i]) * out * (1.0 - out);
   }

   // Backpropagation
   for(int layer = outputLayer; layer > 0; layer--)
   {
      for(int i = 0; i < m_layerSizes[layer]; i++)
      {
         m_biases[biasIndex + i] -= learningRate * errors[neuronIndex + i];
         for(int j = 0; j < m_layerSizes[layer - 1]; j++)
            m_weights[weightIndex + i * m_layerSizes[layer - 1] + j] -=
               learningRate * errors[neuronIndex + i] * m_neurons[neuronIndex - m_layerSizes[layer - 1] + j];
      }

      if(layer > 1)
      {
         int prevNeuronIndex = neuronIndex - m_layerSizes[layer - 1];
         int prevWeightIndex = weightIndex - m_layerSizes[layer - 1] * m_layerSizes[layer - 2];

         for(int j = 0; j < m_layerSizes[layer - 1]; j++)
         {
            double error = 0;
            for(int i = 0; i < m_layerSizes[layer]; i++)
               error += errors[neuronIndex + i] * m_weights[weightIndex + i * m_layerSizes[layer - 1] + j];
            errors[prevNeuronIndex + j] = error * ActivateHiddenDerivative(m_neurons[prevNeuronIndex + j]);
         }

         neuronIndex = prevNeuronIndex;
         weightIndex = prevWeightIndex;
         biasIndex  -= m_layerSizes[layer - 1];
      }
   }
}

void NeuralNetwork::Train(double &inputs[], double &targets[], int epochs, double learningRate)
{
   int inputSize  = ArraySize(inputs)  / m_layerSizes[0];
   int targetSize = ArraySize(targets) / m_layerSizes[m_numLayers - 1];

   Print("Training: ", inputSize, " campioni, ", epochs, " epoche, lr=", learningRate);

   if(inputSize != targetSize)
   {
      Print("Errore: campioni input (", inputSize, ") != campioni target (", targetSize, ")");
      return;
   }

   for(int epoch = 0; epoch < epochs; epoch++)
   {
      double totalLoss = 0.0;

      for(int sample = 0; sample < inputSize; sample++)
      {
         double sampleInputs[];
         double sampleTargets[];
         ArrayResize(sampleInputs,  m_layerSizes[0]);
         ArrayResize(sampleTargets, m_layerSizes[m_numLayers - 1]);

         for(int j = 0; j < m_layerSizes[0]; j++)
            sampleInputs[j] = inputs[sample * m_layerSizes[0] + j];
         for(int j = 0; j < m_layerSizes[m_numLayers - 1]; j++)
            sampleTargets[j] = targets[sample * m_layerSizes[m_numLayers - 1] + j];

         BackPropagate(sampleInputs, sampleTargets, learningRate);

         double outputs[];
         GetOutputs(outputs);
         totalLoss += CrossEntropyLoss(sampleTargets, outputs);
      }

      // Log solo ogni 50 epoche per non intasare il log
      if((epoch + 1) % 50 == 0 || epoch == 0)
         Print("Epoca ", epoch + 1, "/", epochs, " - Loss media: ", DoubleToString(totalLoss / inputSize, 6));
   }

   Print("Training completato.");
}

void NeuralNetwork::PrintWeights()
{
   int weightIndex = 0;
   for(int layer = 0; layer < m_numLayers - 1; layer++)
   {
      Print("Layer ", layer, " weights:");
      for(int i = 0; i < m_layerSizes[layer + 1]; i++)
      {
         string s = "";
         for(int j = 0; j < m_layerSizes[layer]; j++)
            s += DoubleToString(m_weights[weightIndex++], 4) + " ";
         Print("  Neuron ", i, ": ", s);
      }
   }
}

double NeuralNetwork::CrossEntropyLoss(double &targets[], double &outputs[])
{
   double sum     = 0;
   double epsilon = 1e-15;
   int    size    = MathMin(ArraySize(targets), ArraySize(outputs));
   for(int i = 0; i < size; i++)
      sum += targets[i] * MathLog(outputs[i] + epsilon) + (1.0 - targets[i]) * MathLog(1.0 - outputs[i] + epsilon);
   return -sum / size;
}

string NeuralNetwork::DoubleArrayToString(const double &arr[], int start = 0, int count = WHOLE_ARRAY)
{
   string result = "";
   int    size   = ArraySize(arr);
   if(start < 0 || start >= size) return result;
   if(count == WHOLE_ARRAY || count > size - start) count = size - start;
   for(int i = start; i < start + count; i++)
   {
      if(i > start) result += ", ";
      result += DoubleToString(arr[i], 6);
   }
   return result;
}

bool NeuralNetwork::AreInputsInRange(const double &inputs[])
{
   int size = ArraySize(inputs);
   for(int i = 0; i < size; i++)
      if(inputs[i] < -1.0 || inputs[i] > 1.0)
         return false;
   return true;
}

bool NeuralNetwork::AreTargetsInRange(const double &targets[])
{
   int size = ArraySize(targets);
   for(int i = 0; i < size; i++)
      if(targets[i] < 0.0 || targets[i] > 1.0)
         return false;
   return true;
}
