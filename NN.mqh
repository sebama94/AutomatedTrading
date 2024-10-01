//+------------------------------------------------------------------+
//|                                                           NN.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include <Arrays\ArrayString.mqh>

#define MAX_LAYERS 10
#define MAX_NEURONS 100000

//+------------------------------------------------------------------+
//| Neural Network Class                                             |
//+------------------------------------------------------------------+
class NeuralNetwork
  {
private:
   int               m_numLayers;
   int               m_layerSizes[];
   double            m_neurons[];
   double            m_weights[];
   double            m_biases[];
   double            m_learningRate;

public:
                     NeuralNetwork(double learningRate=0.01);
                    ~NeuralNetwork();
   
   bool              Initialize(int &layerSizes[], int numLayers);
   void              SetWeights(double &weights[]);
   void              SetBiases(double &biases[]);
   void              FeedForward(double &inputs[]);
   void              GetOutputs(double &outputs[]);
   void              BuildModel(int &layerSizes[], int numLayers);
   void              Train(double &inputs[], double &targets[], int epochs, double learningRate);
   void              PrintWeights();
   
private:
   double            ActivateHidden(double x);
   double            ActivateHiddenDerivative(double x);
   void              ActivateOutput(double &x[], int size, int startIndex);
   void              ActivateOutputDerivative(double &x[], double &result[], int size);
   void              BackPropagate(double &inputs[], double &targets[], double learningRate);
   double            CrossEntropyLoss(double &targets[], double &outputs[]);
   string            DoubleArrayToString(const double &arr[], int start=0, int count=WHOLE_ARRAY);
   void              ValidateInputs(double &inputs[], double &targets[]);
   bool              AreInputsInRange(const double &inputs[]);
   bool              AreTargetsInRange(const double &targets[]);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
NeuralNetwork::NeuralNetwork(double learningRate=0.01)
  {
   m_numLayers = 0;
   m_learningRate = learningRate;
   ArrayInitialize(m_layerSizes, 0);
   ArrayResize(m_neurons, 0);
   ArrayResize(m_weights, 0);
   ArrayResize(m_biases, 0);
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
NeuralNetwork::~NeuralNetwork()
  {
  }

//+------------------------------------------------------------------+
//| Initialize the neural network                                    |
//+------------------------------------------------------------------+
bool NeuralNetwork::Initialize(int &layerSizes[], int numLayers)
  {
   if(numLayers > MAX_LAYERS)
     {
      Print("Error: Number of layers exceeds MAX_LAYERS");
      return false;
     }

   m_numLayers = numLayers;
   ArrayResize(m_layerSizes, m_numLayers);
   int totalNeurons = 0;
   for(int i = 0; i < numLayers; i++)
     {
      if(layerSizes[i] > MAX_NEURONS)
        {
         Print("Error: Number of neurons in layer ", i, " exceeds MAX_NEURONS");
         return false;
        }
      m_layerSizes[i] = layerSizes[i];
      totalNeurons += layerSizes[i];
     }
   
   ArrayResize(m_neurons, totalNeurons);
   ArrayInitialize(m_neurons, 0);
   
   int totalWeights = 0;
   int totalBiases = 0;
   for(int i = 0; i < numLayers - 1; i++)
     {
      totalWeights += layerSizes[i] * layerSizes[i+1];
      totalBiases += layerSizes[i+1];
     }
   
   ArrayResize(m_weights, totalWeights);
   ArrayInitialize(m_weights, 0);
   
   ArrayResize(m_biases, totalBiases);
   ArrayInitialize(m_biases, 0);
   
   return true;
  }

//+------------------------------------------------------------------+
//| Set weights for the neural network                               |
//+------------------------------------------------------------------+
void NeuralNetwork::SetWeights(double &weights[])
  {
   if(ArraySize(weights) != ArraySize(m_weights))
     {
      Print("Error: Weights array size mismatch");
      return;
     }
   ArrayCopy(m_weights, weights);
  }

//+------------------------------------------------------------------+
//| Set biases for the neural network                                |
//+------------------------------------------------------------------+
void NeuralNetwork::SetBiases(double &biases[])
  {
   if(ArraySize(biases) != ArraySize(m_biases))
     {
      Print("Error: Biases array size mismatch");
      return;
     }
   ArrayCopy(m_biases, biases);
  }

//+------------------------------------------------------------------+
//| Feed forward through the neural network                          |
//+------------------------------------------------------------------+
void NeuralNetwork::FeedForward(double &inputs[])
  {
   if(ArraySize(inputs) < m_layerSizes[0])
     {
      Print("Error: Input size is smaller than the input layer size");
      return;
     }
   
   if(!AreInputsInRange(inputs))
     {
      Print("Error: Input values are out of range [-1, 1]");
      return;
     }
   
   int neuronIndex = 0;
   int weightIndex = 0;
   int biasIndex = 0;
   
   // Set input layer
   for(int i = 0; i < m_layerSizes[0]; i++)
     {
      m_neurons[neuronIndex++] = inputs[i];
     }
   
   // Feed forward through hidden layers and output layer
   for(int layer = 1; layer < m_numLayers; layer++)
     {
      for(int i = 0; i < m_layerSizes[layer]; i++)
        {
         double sum = 0;
         for(int j = 0; j < m_layerSizes[layer-1]; j++)
           {
            sum += m_neurons[neuronIndex - m_layerSizes[layer-1] + j] * m_weights[weightIndex++];
           }
         sum += m_biases[biasIndex++];
         
         if(layer == m_numLayers - 1)
           {
            // Output layer
            m_neurons[neuronIndex++] = sum; // Linear activation for output layer
           }
         else
           {
            // Hidden layer
            m_neurons[neuronIndex++] = ActivateHidden(sum);
           }
        }
     }
   
   // Apply softmax to output layer
   int outputLayerStart = ArraySize(m_neurons) - m_layerSizes[m_numLayers - 1];
   ActivateOutput(m_neurons, m_layerSizes[m_numLayers - 1], outputLayerStart);
   
   // Debug print to check the output layer values after softmax
   Print("Output layer values after softmax: ", DoubleArrayToString(m_neurons, outputLayerStart, m_layerSizes[m_numLayers - 1]));
  }

//+------------------------------------------------------------------+
//| Get the outputs of the neural network                            |
//+------------------------------------------------------------------+
void NeuralNetwork::GetOutputs(double &outputs[])
  {
   int outputLayer = m_numLayers - 1;
   int outputStart = ArraySize(m_neurons) - m_layerSizes[outputLayer];
   
   if(ArrayResize(outputs, m_layerSizes[outputLayer]) != m_layerSizes[outputLayer])
     {
      Print("Error: Failed to resize outputs array");
      return;
     }
   
   for(int i = 0; i < m_layerSizes[outputLayer]; i++)
     {
      outputs[i] = m_neurons[outputStart + i];
     }
  }

//+------------------------------------------------------------------+
//| Build the model                                                  |
//+------------------------------------------------------------------+
void NeuralNetwork::BuildModel(int &layerSizes[], int numLayers)
{
   if(Initialize(layerSizes, numLayers))
   {
      double weights[];
      double biases[];
      
      ArrayResize(weights, ArraySize(m_weights));
      ArrayResize(biases, ArraySize(m_biases));
      
      int weightIndex = 0;
      int biasIndex = 0;
      
      for(int layer = 0; layer < numLayers - 1; layer++)
      {
         int fanIn = layerSizes[layer];
         int fanOut = layerSizes[layer + 1];
         
         for(int i = 0; i < fanOut; i++)
         {
            for(int j = 0; j < fanIn; j++)
            {
               weights[weightIndex++] = (MathRand() / 32768.0) * 0.01; // Scale down to small values
            }
            biases[biasIndex++] = 0;  // You can start biases at zero
         }
      }
      
      SetWeights(weights);
      SetBiases(biases);
   }
   else
   {
      Print("Failed to initialize the neural network");
   }
}

//+------------------------------------------------------------------+
//| Activation function for hidden layers (Hyperbolic Tangent)       |
//+------------------------------------------------------------------+
double NeuralNetwork::ActivateHidden(double x)
  {
   return MathTanh(x);
  }

//+------------------------------------------------------------------+
//| Derivative of activation function for hidden layers              |
//+------------------------------------------------------------------+
double NeuralNetwork::ActivateHiddenDerivative(double x)
  {
   double tanh = MathTanh(x);
   return 1 - tanh * tanh;
  }

//+------------------------------------------------------------------+
//| Activation function for output layer (Softmax)                   |
//+------------------------------------------------------------------+
void NeuralNetwork::ActivateOutput(double &x[], int size, int startIndex)
  {
   double max = x[ArrayMaximum(x, startIndex, size)];
   double sum = 0;
   for(int i = 0; i < size; i++)
     {
      x[startIndex + i] = MathExp(x[startIndex + i] - max);
      sum += x[startIndex + i];
     }
   for(int i = 0; i < size; i++)
     {
      x[startIndex + i] /= sum;
     }
  }

//+------------------------------------------------------------------+
//| Derivative of activation function for output layer               |
//+------------------------------------------------------------------+
void NeuralNetwork::ActivateOutputDerivative(double &x[], double &result[], int size)
  {
   for(int i = 0; i < size; i++)
     {
      result[i] = x[i] * (1 - x[i]);
     }
  }

//+------------------------------------------------------------------+
//| Back propagation                                                 |
//+------------------------------------------------------------------+
void NeuralNetwork::BackPropagate(double &inputs[], double &targets[], double learningRate)
{
   if(!AreInputsInRange(inputs))
     {
      Print("Error: Input values are out of range [-1, 1]");
      return;
     }

   if(!AreTargetsInRange(targets))
     {
      Print("Error: Target values are out of range [0, 1]");
      return;
     }

   FeedForward(inputs);

   int outputLayer = m_numLayers - 1;
   double errors[];
   ArrayResize(errors, ArraySize(m_neurons));
   
   if(ArraySize(targets) < m_layerSizes[outputLayer])
   {
      Print("Error: Targets array is smaller than the output layer size");
      return;
   }

   int neuronIndex = ArraySize(m_neurons) - m_layerSizes[outputLayer];
   int weightIndex = ArraySize(m_weights) - m_layerSizes[outputLayer] * m_layerSizes[outputLayer - 1];
   int biasIndex = ArraySize(m_biases) - m_layerSizes[outputLayer];

   // Calculate output layer errors (using cross-entropy derivative)
   for(int i = 0; i < m_layerSizes[outputLayer]; i++)
   {
      errors[neuronIndex + i] = m_neurons[neuronIndex + i] - targets[i];  
   }

   // Print softmax output and target
   Print("Softmax output: ", DoubleArrayToString(m_neurons, neuronIndex, m_layerSizes[outputLayer]));
   Print("Target: ", DoubleArrayToString(targets, 0, m_layerSizes[outputLayer]));

   // Backpropagate errors
   for(int layer = outputLayer; layer > 0; layer--)
   {
      for(int i = 0; i < m_layerSizes[layer]; i++)
      {
         // Update biases
         m_biases[biasIndex + i] -= learningRate * errors[neuronIndex + i];

         // Update weights
         for(int j = 0; j < m_layerSizes[layer-1]; j++)
         {
            m_weights[weightIndex + i * m_layerSizes[layer-1] + j] -= learningRate * errors[neuronIndex + i] * m_neurons[neuronIndex - m_layerSizes[layer-1] + j];
         }
      }

      // Calculate errors for the previous layer
      if(layer > 1)
      {
         int prevNeuronIndex = neuronIndex - m_layerSizes[layer-1];
         int prevWeightIndex = weightIndex - m_layerSizes[layer-1] * m_layerSizes[layer-2];

         for(int j = 0; j < m_layerSizes[layer-1]; j++)
         {
            double error = 0;
            for(int i = 0; i < m_layerSizes[layer]; i++)
            {
               error += errors[neuronIndex + i] * m_weights[weightIndex + i * m_layerSizes[layer-1] + j];
            }
            errors[prevNeuronIndex + j] = error * ActivateHiddenDerivative(m_neurons[prevNeuronIndex + j]);
         }

         neuronIndex = prevNeuronIndex;
         weightIndex = prevWeightIndex;
         biasIndex -= m_layerSizes[layer-1];
      }
   }
}

//+------------------------------------------------------------------+
//| Train the neural network                                         |
//+------------------------------------------------------------------+
void NeuralNetwork::Train(double &inputs[], double &targets[], int epochs, double learningRate)
{
   int inputSize = ArraySize(inputs) / m_layerSizes[0];
   int targetSize = ArraySize(targets) / m_layerSizes[m_numLayers-1];

   Print("Starting training with ", inputSize, " samples, ", epochs, " epochs, learning rate ", learningRate);
   Print("Input size: ", ArraySize(inputs), ", Target size: ", ArraySize(targets));

   ValidateInputs(inputs, targets);

   if(inputSize != targetSize)
   {
      Print("Error: Number of input samples does not match number of target samples");
      return;
   }

   for(int epoch = 0; epoch < epochs; epoch++)
   {
      double totalLoss = 0.0;
      for(int sample = 0; sample < inputSize; sample++)
      {
         double sampleInputs[];
         double sampleTargets[];

         ArrayResize(sampleInputs, m_layerSizes[0]);
         ArrayResize(sampleTargets, m_layerSizes[m_numLayers-1]);

         for(int j = 0; j < m_layerSizes[0]; j++)
         {
            sampleInputs[j] = inputs[sample * m_layerSizes[0] + j];
         }
         for(int j = 0; j < m_layerSizes[m_numLayers-1]; j++)
         {
            sampleTargets[j] = targets[sample * m_layerSizes[m_numLayers-1] + j];
         }

         BackPropagate(sampleInputs, sampleTargets, learningRate);

         // Calculate loss for this sample
         double outputs[];
         GetOutputs(outputs);

         double sampleLoss = CrossEntropyLoss(sampleTargets, outputs);
         totalLoss += sampleLoss;

         // Print debug information for each sample
         Print("Epoch ", epoch + 1, ", Sample ", sample + 1, " - Loss: ", DoubleToString(sampleLoss, 6));
         Print("NN Output: ", DoubleArrayToString(outputs));
         Print("Target: ", DoubleArrayToString(sampleTargets));
      }

      // Calculate average loss for this epoch
      double avgLoss = totalLoss / inputSize;
      Print("Epoch ", epoch + 1, " completed with average loss: ", DoubleToString(avgLoss, 6));
   }

   Print("Training completed.");
}

//+------------------------------------------------------------------+
//| Print weights of the neural network                              |
//+------------------------------------------------------------------+
void NeuralNetwork::PrintWeights()
  {
   int weightIndex = 0;
   for(int layer = 0; layer < m_numLayers - 1; layer++)
     {
      Print("Layer ", layer, " weights:");
      for(int i = 0; i < m_layerSizes[layer+1]; i++)
        {
         string weightStr = "";
         for(int j = 0; j < m_layerSizes[layer]; j++)
           {
            weightStr += DoubleToString(m_weights[weightIndex++], 4) + " ";
           }
         Print("  Neuron ", i, ": ", weightStr);
        }
     }
  }

//+------------------------------------------------------------------+
//| Cross Entropy Loss                                               |
//+------------------------------------------------------------------+
double NeuralNetwork::CrossEntropyLoss(double &targets[], double &outputs[])
{
   double sum = 0;
   int size = MathMin(ArraySize(targets), ArraySize(outputs));
   
   for(int i = 0; i < size; i++)
   {
      // Add a small epsilon to avoid log(0)
      double epsilon = 1e-15;
      sum += targets[i] * MathLog(outputs[i] + epsilon) + (1 - targets[i]) * MathLog(1 - outputs[i] + epsilon);
   }
   
   return -sum / size;
}

//+------------------------------------------------------------------+
//| Convert double array to string                                   |
//+------------------------------------------------------------------+
string NeuralNetwork::DoubleArrayToString(const double &arr[], int start=0, int count=WHOLE_ARRAY)
  {
   string result = "";
   int size = ArraySize(arr);
   
   if(start < 0 || start >= size)
      return result;
   
   if(count == WHOLE_ARRAY || count > size - start)
      count = size - start;
   
   for(int i = start; i < start + count; i++)
     {
      if(i > start)
         result += ", ";
      result += DoubleToString(arr[i], 8);
     }
   
   return result;
  }

//+------------------------------------------------------------------+
//| Validate inputs and targets                                      |
//+------------------------------------------------------------------+
void NeuralNetwork::ValidateInputs(double &inputs[], double &targets[])
  {
   int inputSize = ArraySize(inputs);
   int targetSize = ArraySize(targets);
   int expectedInputSize = m_layerSizes[0];
   int expectedTargetSize = m_layerSizes[m_numLayers-1];
   
   if(inputSize % expectedInputSize != 0)
     {
      Print("Error: Input size ", inputSize, " is not a multiple of the input layer size ", expectedInputSize);
     }
   
   if(targetSize % expectedTargetSize != 0)
     {
      Print("Error: Target size ", targetSize, " is not a multiple of the output layer size ", expectedTargetSize);
     }
   
   if(inputSize / expectedInputSize != targetSize / expectedTargetSize)
     {
      Print("Error: Number of input samples (", inputSize / expectedInputSize, 
            ") does not match number of target samples (", targetSize / expectedTargetSize, ")");
     }
   
   // Check if all target values are valid (0 or 1 for binary classification)
   for(int i = 0; i < targetSize; i++)
     {
      if(targets[i] != 0 && targets[i] != 1)
        {
         Print("Error: Invalid target value ", targets[i], " at index ", i, ". Expected 0 or 1 for binary classification.");
        }
     }
  }

//+------------------------------------------------------------------+
//| Check if inputs are within the range [-1, 1]                     |
//+------------------------------------------------------------------+
bool NeuralNetwork::AreInputsInRange(const double &inputs[])
  {
   int size = ArraySize(inputs);
   for(int i = 0; i < size; i++)
     {
      if(inputs[i] < -1 || inputs[i] > 1)
        {
         return false;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Check if targets are within the range [0, 1]                     |
//+------------------------------------------------------------------+
bool NeuralNetwork::AreTargetsInRange(const double &targets[])
  {
   int size = ArraySize(targets);
   for(int i = 0; i < size; i++)
     {
      if(targets[i] < 0 || targets[i] > 1)
        {
         return false;
        }
     }
   return true;
  }