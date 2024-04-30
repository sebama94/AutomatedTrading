//+------------------------------------------------------------------+
//|                                            DeepNeuralNetwork.mqh |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#define SIZEI 16
#define SIZEA 12
#define SIZEB 8
#define SIZEC 5
#define SIZEO 2  // New layer size
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class DeepNeuralNetwork
{
private:

   int               numInput;
   int               numHiddenA;
   int               numHiddenB;
   int               numHiddenC;
   int               numOutput;

   double            inputs[];

   double            iaWeights[][SIZEA];
   double            abWeights[][SIZEB];
   double            bcWeights[][SIZEC];  // Weights for new layer to output
   double            coWeights[][SIZEO];

   double            aBiases[];
   double            bBiases[];
   double            cBiases[];
   double            oBiases[];

   double            aOutputs[];
   double            bOutputs[];
   double            cOutputs[];
   double            outputs[];

public:
DeepNeuralNetwork(){};
void Init(int _numInput, int _numHiddenA, int _numHiddenB, int _numHiddenC, int _numOutput)
   {
      this.numInput = _numInput;
      this.numHiddenA = _numHiddenA;
      this.numHiddenB = _numHiddenB;
      this.numHiddenC = _numHiddenC;  
      this.numOutput = _numOutput;

      ArrayResize(inputs, numInput);

      ArrayResize(iaWeights, numInput);
      ArrayResize(abWeights, numHiddenA);
      ArrayResize(bcWeights, numHiddenB);  // Resize new layer weights
      ArrayResize(coWeights, numHiddenC);  // Resize new layer weights

      ArrayResize(aBiases, numHiddenA);
      ArrayResize(bBiases, numHiddenB);
      ArrayResize(cBiases, numHiddenC);
      ArrayResize(oBiases, numOutput);

      ArrayResize(aOutputs, numHiddenA);
      ArrayResize(bOutputs, numHiddenB);
      ArrayResize(cOutputs, numHiddenC);
      ArrayResize(outputs, numOutput);
   }

   void SetWeights(double &weights[])
   {
      int numWeights = (numInput * numHiddenA) + numHiddenA +
                       (numHiddenA * numHiddenB) + numHiddenB +
                       (numHiddenB * numHiddenC) + numHiddenC +   
                       (numHiddenC * numOutput) + numOutput;    

      if(ArraySize(weights) != numWeights)
      {
         Print("Incorrect weights length");
         return;
      }

      int k = 0;


      for(int i=0; i<numInput;++i)
         for(int j=0; j<numHiddenA;++j)
            iaWeights[i][j]=NormalizeDouble(weights[k++],2);

      for(int i=0; i<numHiddenA;++i)
         aBiases[i]=NormalizeDouble(weights[k++],2);

      for(int i=0; i<numHiddenA;++i)
         for(int j=0; j<numHiddenB;++j)
            abWeights[i][j]=NormalizeDouble(weights[k++],2);

      for(int i=0; i<numHiddenB;++i)
         bBiases[i]=NormalizeDouble(weights[k++],2);

      for(int i=0; i<numHiddenB;++i)
         for(int j=0; j<numHiddenC;++j)
            bcWeights[i][j]=NormalizeDouble(weights[k++],2);

      for(int i=0; i<numHiddenC;++i)
         cBiases[i]=NormalizeDouble(weights[k++],2);

      for(int i=0; i<numHiddenC;++i)
         for(int j=0; j<numOutput;++j)
            coWeights[i][j]=NormalizeDouble(weights[k++],2);
      
      for(int i = 0; i < numOutput; ++i)
         oBiases[i] = NormalizeDouble(weights[k++], 2);

   }


   void ComputeOutputs(double &xValues[], double &yValues[])
   {
      double aSums[], bSums[], cSums[], oSums[];  // Sums for each layer

      // Initialize arrays for each layer's sums and outputs
      ArrayResize(aSums, numHiddenA);
      ArrayResize(bSums, numHiddenB);
      ArrayResize(cSums, numHiddenC);
      ArrayResize(oSums, numOutput);

      ArrayFill(aSums, 0, numHiddenA, 0);
      ArrayFill(bSums, 0, numHiddenB, 0);
      ArrayFill(cSums, 0, numHiddenC, 0);
      ArrayFill(oSums, 0, numOutput, 0);

      // Copy x-values to inputs
      for(int i = 0; i < ArraySize(xValues); ++i)
         inputs[i] = xValues[i];

      // Calculate sums for each layer and apply activation functions
      for(int j = 0; j < numHiddenA; ++j)
         for(int i = 0; i < numInput; ++i)
            aSums[j] += inputs[i] * iaWeights[i][j];

      for(int i = 0; i < numHiddenA; ++i)
         aSums[i] += aBiases[i];

      for(int i = 0; i < numHiddenA; ++i)
         aOutputs[i] = HyperTanFunction(aSums[i]);

      for(int j = 0; j < numHiddenB; ++j)
         for(int i = 0; i < numHiddenA; ++i)
            bSums[j] += aOutputs[i] * abWeights[i][j];

      for(int i = 0; i < numHiddenB; ++i)
         bSums[i] += bBiases[i];

      for(int i = 0; i < numHiddenB; ++i)
         bOutputs[i] = HyperTanFunction(bSums[i]);

      for(int j = 0; j < numHiddenC; ++j)
         for(int i = 0; i < numHiddenB; ++i)
            cSums[j] += bOutputs[i] * bcWeights[i][j];

      for(int i = 0; i < numHiddenC; ++i)
         cSums[i] += cBiases[i];

      for(int i = 0; i < numHiddenC; ++i)
         cOutputs[i] = HyperTanFunction(cSums[i]);

      for(int j = 0; j < numOutput; ++j)
         for(int i = 0; i < numHiddenC; ++i)
            oSums[j] += cOutputs[i] * coWeights[i][j];

      for(int i = 0; i < numOutput; ++i)
         oSums[i] += oBiases[i];

      double softOut[];
      Softmax(oSums, softOut);
      ArrayCopy(outputs, softOut);

      ArrayCopy(yValues, outputs);

   }


   double HyperTanFunction(double x)
   {
      if(x<-20.0) return -1.0; // approximation is correct to 30 decimals
      else if(x > 20.0) return 1.0;
      else return (1-exp(-2*x))/(1+exp(-2*x));//MathTanh(x);
   }

   void Softmax(double &oSums[],double &_softOut[])
   {
      // determine max output sum
      // does all output nodes at once so scale doesn't have to be re-computed each time
      int size=ArraySize(oSums);
      double max= oSums[0];
      for(int i = 0; i<size;++i)
         if(oSums[i]>max) max=oSums[i];

      // determine scaling factor -- sum of exp(each val - max)
      double scale=0.0;
      for(int i= 0; i<size;++i)
         scale+= MathExp(oSums[i]-max);

      ArrayResize(_softOut,size);
      for(int i=0; i<size;++i)
         _softOut[i]=MathExp(oSums[i]-max)/scale;

   }

};
//+------------------------------------------------------------------+
