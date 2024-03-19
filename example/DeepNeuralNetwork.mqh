//+------------------------------------------------------------------+
//|                                            DeepNeuralNetwork.mqh |
//|                        Copyright 2018, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#define SIZEI 4
#define SIZEA 5
#define SIZEB 3
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class DeepNeuralNetwork
  {
private:

   int               numInput;
   int               numHiddenA;
   int               numHiddenB;
   int               numOutput;

   double            inputs[];

   double            iaWeights[][SIZEI];
   double            abWeights[][SIZEA];
   double            boWeights[][SIZEB];

   double            aBiases[];
   double            bBiases[];
   double            oBiases[];

   double            aOutputs[];
   double            bOutputs[];
   double            outputs[];

public:

                     DeepNeuralNetwork(int _numInput,int _numHiddenA,int _numHiddenB,int _numOutput)
     {

      this.numInput=_numInput;
      this.numHiddenA = _numHiddenA;
      this.numHiddenB = _numHiddenB;
      this.numOutput=_numOutput;

      ArrayResize(inputs,numInput);

      ArrayResize(iaWeights,numInput);
      ArrayResize(abWeights,numHiddenA);
      ArrayResize(boWeights,numHiddenB);

      ArrayResize(aBiases,numHiddenA);
      ArrayResize(bBiases,numHiddenB);
      ArrayResize(oBiases,numOutput);

      ArrayResize(aOutputs,numHiddenA);
      ArrayResize(bOutputs,numHiddenB);
      ArrayResize(outputs,numOutput);
     }

   void SetWeights(double &weights[])
     {
      int numWeights=(numInput*numHiddenA)+numHiddenA+(numHiddenA*numHiddenB)+numHiddenB+(numHiddenB*numOutput)+numOutput;
      if(ArraySize(weights)!=numWeights)
        {
         Print("Bad weights length");
         return;
        }

      int k=0;

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
         for(int j=0; j<numOutput;++j)
            boWeights[i][j]=NormalizeDouble(weights[k++],2);

      for(int i=0; i<numOutput;++i)
         oBiases[i]=NormalizeDouble(weights[k++],2);
     }

   void ComputeOutputs(double &xValues[],double &yValues[])
     {
      double aSums[]; // hidden A nodes sums scratch array
      double bSums[]; // hidden B nodes sums scratch array
      double oSums[]; // output nodes sums

      ArrayResize(aSums,numHiddenA);
      ArrayFill(aSums,0,numHiddenA,0);
      ArrayResize(bSums,numHiddenB);
      ArrayFill(bSums,0,numHiddenB,0);
      ArrayResize(oSums,numOutput);
      ArrayFill(oSums,0,numOutput,0);

      int size=ArraySize(xValues);

      for(int i=0; i<size;++i) // copy x-values to inputs
         this.inputs[i]=xValues[i];

      for(int j=0; j<numHiddenA;++j) // compute sum of (ia) weights * inputs
         for(int i=0; i<numInput;++i)
            aSums[j]+=this.inputs[i]*this.iaWeights[i][j]; // note +=

      for(int i=0; i<numHiddenA;++i) // add biases to a sums
         aSums[i]+=this.aBiases[i];

      for(int i=0; i<numHiddenA;++i) // apply activation
         this.aOutputs[i]=HyperTanFunction(aSums[i]); // hard-coded

      for(int j=0; j<numHiddenB;++j) // compute sum of (ab) weights * a outputs = local inputs
         for(int i=0; i<numHiddenA;++i)
            bSums[j]+=aOutputs[i]*this.abWeights[i][j]; // note +=

      for(int i=0; i<numHiddenB;++i) // add biases to b sums
         bSums[i]+=this.bBiases[i];

      for(int i=0; i<numHiddenB;++i) // apply activation
         this.bOutputs[i]=HyperTanFunction(bSums[i]); // hard-coded

      for(int j=0; j<numOutput;++j) // compute sum of (bo) weights * b outputs = local inputs
         for(int i=0; i<numHiddenB;++i)
            oSums[j]+=bOutputs[i]*boWeights[i][j];

      for(int i=0; i<numOutput;++i) // add biases to input-to-hidden sums
         oSums[i]+=oBiases[i];

      double softOut[];
      Softmax(oSums,softOut); // softmax activation does all outputs at once for efficiency
      ArrayCopy(outputs,softOut);

      ArrayCopy(yValues,this.outputs);

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
