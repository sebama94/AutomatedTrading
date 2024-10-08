//+------------------------------------------------------------------+
//|                                                     NeuroNet.mqh |
//|                                              Copyright 2019, DNG |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, DNG"
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include <Arrays\ArrayDouble.mqh>
#include <Arrays\ArrayInt.mqh>
#include <Arrays\ArrayObj.mqh>
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CConnection : public CObject
  {
public:
   double            weight;
   double            deltaWeight;
                     CConnection(double w) { weight=w; deltaWeight=0; }
                    ~CConnection(){};
   //--- methods for working with files
   virtual bool      Save(const int file_handle);
   virtual bool      Load(const int file_handle);
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CConnection::Save(const int file_handle)
  {
   if(file_handle==INVALID_HANDLE)
      return false;
//---
   if(FileWriteDouble(file_handle,weight)<=0)
      return false;
   if(FileWriteDouble(file_handle,deltaWeight)<=0)
      return false;
//---
   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CConnection::Load(const int file_handle)
  {
   if(file_handle==INVALID_HANDLE)
      return false;
//---
   weight=FileReadDouble(file_handle);
   deltaWeight=FileReadDouble(file_handle);
//---
   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CArrayCon  :    public CArrayObj
  {
public:
                     CArrayCon(void){};
                    ~CArrayCon(void){};
   //---
   virtual bool      CreateElement(const int index);
   virtual int       Type(void) const { return(0x7781); }
   };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CArrayCon::CreateElement(const int index)
  {
   if(index<0)
      return false;
//---
   if(m_data_max<index+1)
     {
      if(ArrayResize(m_data,index+10)<=0)
         return false;
      m_data_max=ArraySize(m_data);
     }
//---
   m_data[index]=new CConnection((MathRand()+1)/32768.0);
   if(!CheckPointer(m_data[index])!=POINTER_INVALID)
      return false;
   m_data_total=MathMax(m_data_total,index);
//---
   return (true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CNeuron  :  public CObject
  {
public:
                     CNeuron(uint numOutputs,uint myIndex);
                    ~CNeuron() {};
   void              setOutputVal(double val) { outputVal=val; }
   double            getOutputVal() const { return outputVal; }
   void              feedForward(const CArrayObj *&prevLayer);
   void              calcOutputGradients(double targetVals);
   void              calcHiddenGradients(const CArrayObj *&nextLayer);
   void              updateInputWeights(CArrayObj *&prevLayer);
   //--- methods for working with files
   virtual bool      Save(const int file_handle)                         { return(outputWeights.Save(file_handle));   }
   virtual bool      Load(const int file_handle)                         { return(outputWeights.Load(file_handle));   }

private:
   double            eta;
   double            alpha;
   static double     randomWeight() { return(double)MathRand()/32767.0; }
   static double     activationFunction(double x);
   static double     activationFunctionDerivative(double x);
   double            sumDOW(const CArrayObj *&nextLayer) const;
   double            outputVal;
   CArrayCon         outputWeights;
   uint              m_myIndex;
   double            gradient;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CNeuron::CNeuron(uint numOutputs, uint myIndex)  :  eta(0.15), // net learning rate
                                                    alpha(0.5) // momentum  
  {
   for(uint c=0; c<numOutputs; c++)
     {
      outputWeights.CreateElement(c);
     }

   m_myIndex=myIndex;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CNeuron::updateInputWeights(CArrayObj *&prevLayer)
  {
   int total=prevLayer.Total();
   for(int n=0; n<total && !IsStopped(); n++)
     {
      CNeuron *neuron= prevLayer.At(n);
      CConnection *con=neuron.outputWeights.At(m_myIndex);
      
      con.weight+=con.deltaWeight=(gradient!=0 ? eta*neuron.getOutputVal()*gradient : 0)+(con.deltaWeight!=0 ? alpha*con.deltaWeight : 0);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CNeuron::sumDOW(const CArrayObj *&nextLayer) const
  {
   double sum=0.0;
   int total=nextLayer.Total()-1;
   for(int n=0; n<total; n++)
     {
      CConnection *con=outputWeights.At(n);
      double weight=con.weight;
      if(weight!=0)
        {
         CNeuron *neuron=nextLayer.At(n);
         sum+=weight*neuron.gradient;
        }
     }

   return sum;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CNeuron::calcHiddenGradients(const CArrayObj *&nextLayer)
  {
   double dow=NormalizeDouble(sumDOW(nextLayer),5);
   gradient=(dow!=0 ? dow*CNeuron::activationFunctionDerivative(outputVal) : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CNeuron::calcOutputGradients(double targetVals)
  {
   double delta=NormalizeDouble(targetVals-outputVal,5);
   gradient=(delta!=0 ? delta*CNeuron::activationFunctionDerivative(outputVal) : 0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CNeuron::activationFunction(double x)
  {
//output range [-1.0..1.0]
   return tanh(x);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CNeuron::activationFunctionDerivative(double x)
  {
   return 1/MathPow(cosh(x),2);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CNeuron::feedForward(const CArrayObj *&prevLayer)
  {
   double sum=0.0;
   int total=prevLayer.Total();
   for(int n=0; n<total && !IsStopped(); n++)
     {
      CNeuron *temp=prevLayer.At(n);
      double val=temp.getOutputVal();
      if(val!=0)
        {
         CConnection *con=temp.outputWeights.At(m_myIndex);
         sum+=val * con.weight;
        }
     }

   outputVal=activationFunction(sum);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CLayer: public CArrayObj
  {
private:
   uint              iOutputs;
public:
                     CLayer(const uint outputs=0) { iOutputs=outputs; };
                    ~CLayer(void){};
   //---
   virtual bool      CreateElement(const uint index);
   virtual int       Type(void) const { return(0x7779); }
   };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CLayer::CreateElement(const uint index)
  {
//---
   if(m_data_max<(int)index+1)
     {
      if(ArrayResize(m_data,index+10)<=0)
         return false;
      m_data_max=ArraySize(m_data)-1;
     }
//---
   CNeuron *neuron=new CNeuron(iOutputs,index);
   if(!CheckPointer(neuron)!=POINTER_INVALID)
      return false;
   neuron.setOutputVal((index%3)-1);  
//---
   m_data[index]=neuron;
   m_data_total=(int)MathMax(m_data_total,index);
//---
   return (true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CArrayLayer  :    public CArrayObj
  {
public:
                     CArrayLayer(void){};
                    ~CArrayLayer(void){};
   //---
   virtual bool      CreateElement(const uint neurons, const uint outputs);
   virtual int       Type(void) const { return(0x7780); }
   };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CArrayLayer::CreateElement(const uint neurons, const uint outputs)
  {
   if(neurons<=0)
      return false;
//---
   if(m_data_max<=m_data_total)
     {
      if(ArrayResize(m_data,m_data_total+10)<=0)
         return false;
      m_data_max=ArraySize(m_data)-1;
     }
//---
   CLayer *layer=new CLayer(outputs);
   if(!CheckPointer(layer)!=POINTER_INVALID)
      return false;
   for(uint i=0; i<neurons; i++)
      if(!layer.CreateElement(i))
         return false;
//---
   m_data[m_data_total]=layer;
   m_data_total++;
//---
   return (true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class CNet
  {
public:
                     CNet(const CArrayInt *topology);
                    ~CNet(){};
   void              feedForward(const CArrayDouble *inputVals);
   void              backProp(const CArrayDouble *targetVals);
   void              getResults(CArrayDouble *&resultVals) const;
   double            getRecentAverageError() const { return recentAverageError; }
   bool              Save(const string file_name, double error, double undefine, double forecast, datetime time, bool common=true);
   bool              Load(const string file_name, double &error, double &undefine, double &forecast, datetime &time, bool common=true);
//---
   static double     recentAverageSmoothingFactor;
private:
   CArrayLayer       layers;
   double            recentAverageError;
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CNet::recentAverageSmoothingFactor=100.0; // Number of training samples to average over
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CNet::CNet(const CArrayInt *topology)
  {
   if(CheckPointer(topology)==POINTER_INVALID)
      return;
//---
   int numLayers=topology.Total();
   for(int layerNum=0; layerNum<numLayers; layerNum++) 
     {
      uint numOutputs=(layerNum==numLayers-1 ? 0 : topology.At(layerNum+1));
      if(!layers.CreateElement(topology.At(layerNum), numOutputs))
         return;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CNet::getResults(CArrayDouble *&resultVals) const
  {
   if(CheckPointer(resultVals)==POINTER_INVALID)
      resultVals=new CArrayDouble();
//---
   resultVals.Clear();
   CArrayObj *Layer=layers.At(layers.Total()-1);
   if(CheckPointer(Layer)==POINTER_INVALID)
     {
      return;
     }
   int total=Layer.Total()-1;
   for(int n=0; n<total; n++)
     {
      CNeuron *neuron=Layer.At(n);
      resultVals.Add(neuron.getOutputVal());
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CNet::backProp(const CArrayDouble *targetVals)
  {
   if(CheckPointer(targetVals)==POINTER_INVALID)
      return;
   CArrayObj *outputLayer=layers.At(layers.Total()-1);
   if(CheckPointer(outputLayer)==POINTER_INVALID)
      return;
//---
   double error=0.0;
   int total=outputLayer.Total()-1;
   for(int n=0; n<total && !IsStopped(); n++)
     {
      CNeuron *neuron=outputLayer.At(n);
      double delta=targetVals[n]-neuron.getOutputVal();
      error+=delta*delta;
     }
   error/= total;
   error = sqrt(error);

   recentAverageError+=(error-recentAverageError)/recentAverageSmoothingFactor;
//---
   for(int n=0; n<total && !IsStopped(); n++)
     {
      CNeuron *neuron=outputLayer.At(n);
      neuron.calcOutputGradients(targetVals.At(n));
     }
//---
   for(int layerNum=layers.Total()-2; layerNum>0; layerNum--)
     {
      CArrayObj *hiddenLayer=layers.At(layerNum);
      CArrayObj *nextLayer=layers.At(layerNum+1);
      total=hiddenLayer.Total();
      for(int n=0; n<total && !IsStopped();++n)
        {
         CNeuron *neuron=hiddenLayer.At(n);
         neuron.calcHiddenGradients(nextLayer);
        }
     }
//---
   for(int layerNum=layers.Total()-1; layerNum>0; layerNum--)
     {
      CArrayObj *layer=layers.At(layerNum);
      CArrayObj *prevLayer=layers.At(layerNum-1);
      total=layer.Total()-1;
      for(int n=0; n<total && !IsStopped(); n++)
        {
         CNeuron *neuron=layer.At(n);
         neuron.updateInputWeights(prevLayer);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CNet::feedForward(const CArrayDouble *inputVals)
  {
   if(CheckPointer(inputVals)==POINTER_INVALID)
      return;
//---
 CLayer *Layer=layers.At(0);
   if(CheckPointer(Layer)==POINTER_INVALID)
     {
      return;
     }
   int total=inputVals.Total();
   if(total!=Layer.Total()-1)
      return;
//---
   for(int i=0; i<total && !IsStopped(); i++) 
     {
      CNeuron *neuron=Layer.At(i);
      neuron.setOutputVal(inputVals.At(i));
     }
//---
   total=layers.Total();
   for(int layerNum=1; layerNum<total && !IsStopped(); layerNum++) 
     {
      CArrayObj *prevLayer = layers.At(layerNum - 1);
      CArrayObj *currLayer = layers.At(layerNum);
      int t=currLayer.Total()-1;
      for(int n=0; n<t && !IsStopped(); n++) 
        {
         CNeuron *neuron=currLayer.At(n);
         neuron.feedForward(prevLayer);
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CNet::Save(const string file_name, double loop_err, double undefine_p, double forecast_er,datetime time, bool common=true)
  {
   if(MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_FORWARD) || MQLInfoInteger(MQL_OPTIMIZATION))
      return true;
   if(file_name==NULL)
      return false;
//---
   int handle=FileOpen(file_name,(common ? FILE_COMMON : 0)|FILE_BIN|FILE_WRITE);
   if(handle==INVALID_HANDLE)
      return false;
//---
   if(FileWriteDouble(handle,loop_err)<=0 || FileWriteDouble(handle,undefine_p)<=0 || FileWriteDouble(handle,forecast_er)<=0 || FileWriteLong(handle,(long)time)<=0)
     {
      FileClose(handle);
      return false;
     }
   bool result=layers.Save(handle);
   FileFlush(handle);
   FileClose(handle);
//---
   return result;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CNet::Load(const string file_name, double &loop_err, double &undefine_p, double &forecast_er, datetime &time, bool common=true)
  {
   if(MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_FORWARD) || MQLInfoInteger(MQL_OPTIMIZATION))
      return false;
//---
   if(file_name==NULL)
      return false;
//---
   int handle=FileOpen(file_name,(common ? FILE_COMMON : 0)|FILE_BIN|FILE_READ);
   if(handle==INVALID_HANDLE)
      return false;
//---
   loop_err=FileReadDouble(handle);
   undefine_p=FileReadDouble(handle);
   forecast_er=FileReadDouble(handle);
   time=(datetime)FileReadLong(handle);
//---
   layers.Clear();
   int i=0,num;
//--- check
//--- read and check start marker - 0xFFFFFFFFFFFFFFFF
   if(FileReadLong(handle)==-1)
     {
      //--- read and check array type
      if(FileReadInteger(handle,INT_VALUE)!=layers.Type())
         return(false);
     }
//--- read array length
   num=FileReadInteger(handle,INT_VALUE);
//--- read array
   if(num!=0)
     {
      for(i=0;i<num;i++)
        {
         //--- create new element
         CLayer *Layer=new CLayer();
         if(!Layer.Load(handle))
            break;
         if(!layers.Add(Layer))
            break;
        }
     }
   FileClose(handle);
//--- result
   return(layers.Total()==num);
  }
//+------------------------------------------------------------------+

