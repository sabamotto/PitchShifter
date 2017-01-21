import java.util.Arrays;

class FFTEffect implements AudioEffect {
  protected FFTProcessor proc;
  protected FFT fft, fftr;
  protected Information info = null;
  
  private int prcs = 1, N = 2;  // 2^prcs
  
  private float[] cw;
  private float[][] buffer, lastFrame;
  private float[][] frame;
  private int halfSize, timeSize, specSize, frameSize;
  private int sampleRate;
  
  private float[] orig;
  
  FFTEffect(int timeSize, float sampleRate, FFTProcessor proc) {
    this.proc = proc;
    setFFT(timeSize, sampleRate);
  }
  FFTEffect(FFT fft, FFTProcessor proc) {
    this.proc = proc;
    setFFT(fft);
  }

  void setFFT(int ts, float sf) {
    timeSize = ts;
    sampleRate = (int) sf;
    
    // initialize
    fft = new FFT(timeSize, sampleRate);
    fftr = new FFT(timeSize, sampleRate);
    fft.window(FFT.HAMMING); // fixed
    fftr.window(FFT.HAMMING);
    specSize = fft.specSize();
    
    initialize();
  }
  void setFFT(FFT fft) {
    setFFT(fft.timeSize(),
           (int)(fft.getBandWidth()*fft.specSize()*0.02)*100);
  }

  void setProcessor(FFTProcessor proc) {
    this.proc = proc;
  }
  FFTProcessor getProcessor() {
    return this.proc;
  }
  
  void setPrecision(int p) {
    prcs = p;
    if (prcs < 1) prcs = 1;
    if (prcs >= halfSize) prcs = halfSize;
    N = (int) pow(2, prcs);
    
    initialize();
  }
  int getPrecision() {
    return prcs;
  }
  
  private void initialize() {
    // defining const variables
    halfSize = timeSize / 2;
    frameSize = timeSize / N;
    
    // calculating convolution coefficients
    cw = new float[halfSize];
    for (int i=0; i<frameSize; i++)  // reversed convolution coefficients
      cw[halfSize-i-1] = (1f + cos(i * PI / (frameSize - 1f))) / 2f;
    
    // initializing each buffers
    buffer = new float[2][];
    lastFrame = new float[2][];
    frame = new float[2][];
    for (int i=0; i<2; i++) {
      buffer[i] = new float[timeSize * 2];
      lastFrame[i] = new float[frameSize];
      frame[i] = new float[timeSize];
    }
    
    orig = new float[specSize];
    
    // create information object
    info = new Information();
    info.channels = 2;
    info.precision = prcs;
    info.totalSamples = 0;
    info.totalTime = 0f;  // sec
    info.frameSize = frameSize;
    info.frameTime = (float)(frameSize) / sampleRate;  // sec
  }
  
  int specSize() {
    return specSize;
  }
  int timeSize() {
    return timeSize;
  }
  int frameSize() {
    return frameSize;
  }
  int sampleRate() {
    return sampleRate;
  }
  
  float getPreBand(int index) {
    return orig[index];
  }
  float getPostBand(int index) {
    return fft.getBand(index);
  }
  
  float indexToFreq(int index) {
    return fft.indexToFreq(index);
  }
  int freqToIndex(float freq) {
    return fft.freqToIndex(freq);
  }
  
  Information getInformation() {
    return info;
  }

  void process(float[] samp) {
    info.channels = 1;

    preProcess(samp);
    
    // making full samples (last frame + new frame)
    System.arraycopy(samp, 0, buffer[0], timeSize, timeSize);
    Arrays.fill(samp, 0);
    
    // copying last processed frame by previous frame
    System.arraycopy(lastFrame[0], 0, samp, 0, frameSize);
    
    // calculation and convolution for frame connection
    for (int i=1; i<=N; i++) {
      // updating information
      info.totalSamples += frameSize;
      info.totalTime += frameSize * info.frameTime;
      
      // cutting frame
      System.arraycopy(buffer[0], i*frameSize, frame[0], 0, timeSize);
      
      // FFT and processing effect
      fft.forward(frame[0]);
      if (i == N) {
        // backup spectrum
        for (int j=0; j<specSize; j++) orig[j] = fft.getBand(j);
      }
      proc.analyze(0, fft);
      proc.process(0, fft);
      fft.inverse(frame[0]);
      inverseWindow(frame[0]);
      
      // convolution and adding
      for (int j=halfSize-frameSize; j<halfSize+frameSize; j++) {
        if (j < halfSize) frame[0][j] = frame[0][j]*cw[j];
        else              frame[0][j] = frame[0][j]*cw[timeSize-j-1];
        int si = i*frameSize + j - halfSize;
        if (si >= 0 && si < timeSize) samp[si] += frame[0][j];
      }
    }
    
    // copying last processed and buffer frame for next frame
    System.arraycopy(frame[0], halfSize, lastFrame[0], 0, frameSize);
    System.arraycopy(buffer[0], timeSize, buffer[0], 0, timeSize);
  }

  void process(float[] left, float[] right) {
    info.channels = 2;

    preProcess(left);
    preProcess(right);
    
    // making full samples (last frame + new frame)
    System.arraycopy(left, 0, buffer[0], timeSize, timeSize);
    System.arraycopy(right, 0, buffer[1], timeSize, timeSize);
    Arrays.fill(left, 0);
    Arrays.fill(right, 0);
    
    // copying last processed frame by previous frame
    System.arraycopy(lastFrame[0], 0, left, 0, frameSize);
    System.arraycopy(lastFrame[1], 0, right, 0, frameSize);
    
    // calculation and convolution for frame connection
    for (int i=1; i<=N; i++) {
      // updating information
      info.totalSamples += frameSize;
      info.totalTime += frameSize * info.frameTime;
      
      // cutting frame
      System.arraycopy(buffer[0], i*frameSize, frame[0], 0, timeSize);
      System.arraycopy(buffer[1], i*frameSize, frame[1], 0, timeSize);
      
      // FFT and processing effect
      fft.forward(frame[0]);
      fftr.forward(frame[1]);
      
      // backup spectrum (only left)
      if (i == N) for (int j=0; j<specSize; j++) orig[j] = fft.getBand(j);
      
      proc.analyze(0, fft);
      proc.analyze(1, fftr);
      
      proc.process(0, fft);
      proc.process(1, fftr);
      
      fft.inverse(frame[0]);
      fftr.inverse(frame[1]);
      
      inverseWindow(frame[0]);
      inverseWindow(frame[1]);
      
      // convolution and adding
      for (int j=halfSize-frameSize; j<halfSize+frameSize; j++) {
        if (j < halfSize) {
          frame[0][j] = frame[0][j]*cw[j];
          frame[1][j] = frame[1][j]*cw[j];
        } else {
          frame[0][j] = frame[0][j]*cw[timeSize-j-1];
          frame[1][j] = frame[1][j]*cw[timeSize-j-1];
        }
        int si = i*frameSize + j - halfSize;
        if (si >= 0 && si < timeSize) {
          left[si] += frame[0][j];
          right[si] += frame[1][j];
        }
      }
    }
    
    // copying last processed and buffer frame for next frame
    System.arraycopy(frame[0], halfSize, lastFrame[0], 0, frameSize);
    System.arraycopy(frame[1], halfSize, lastFrame[1], 0, frameSize);
    System.arraycopy(buffer[0], timeSize, buffer[0], 0, timeSize);
    System.arraycopy(buffer[1], timeSize, buffer[1], 0, timeSize);
  }
  
  void preProcess(float[] samples) {
    for (int n=0; n<samples.length; n++) {
      samples[n] *= 0.99f;
    }
  }
  
  void inverseWindow(float[] samples) {
    for (int n=0; n<samples.length; n++) {
      samples[n] /= 0.54f - 0.46f * cos(TWO_PI * n / (samples.length - 1));
    }
  }
  
  class Information {
    public int channels;
    public int precision;
    public long totalSamples;
    public float totalTime;
    public int frameSize;
    public float frameTime;
  } 
}

class FFTProcessor {
  FFTEffect.Information information; 
  void init(FFTEffect engine) {
    information = engine.getInformation();
  }
  void analyze(int ch, FFT fft) {}
  void process(int ch, FFT fft) {}
}

