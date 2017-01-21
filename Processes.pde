class PitchEffect extends FFTProcessor {
  float shiftRate, gain;
  float smtSR, smtGain;
  PitchEffect() {
    this.shiftRate = smtSR = 1.0;
    this.gain = smtGain = 1.0;
  }
  
  void setShiftRate(float rate) {
    shiftRate = rate;
    if (shiftRate < 0.01f) shiftRate = 0.01f;
    else if (shiftRate > 100f) shiftRate = 100f;
  }
  
  void setGain(float g) {
    gain = g;
    if (gain < 0f) gain = 0f;      // -∞dB
    else if (gain > 2f) gain = 2f; // +6dB
  }
  
  void process(int ch, FFT fft) {
    // smoothing parameters
    if (ch == 0) {
      smtSR = (smtSR*3f + shiftRate)/4f;
      smtGain = (smtGain*3f + gain)/4f;
    }
    // copy fft
    float[] specs = new float[fft.specSize()];
    for (int i=0; i<fft.specSize(); i++) {
      specs[i] = fft.getBand(i) * smtGain;
    }
    // proc
    float maxFreq = fft.indexToFreq(fft.specSize()-1);
    for (int i=0; i<fft.specSize(); i++) {
      float freq = fft.indexToFreq(i) / smtSR;
      if (freq > 0 && freq <= maxFreq) {
        fft.setBand(i, max(0,getFreqForSI(fft,specs,freq)));
      } else {
        fft.setBand(i, 0);
      }
    }
  }
  
  float getFreqForSI(FFT fft, float[] bands, float freq) {
    // get power specified with frequency for Sinc interpolation
    // initialize
    float bwid = fft.getBandWidth();  // Hz
    float fidx = freq / bwid;  // High precision fft index
    int si = int(fidx)-2;
    int ei = si+4;
    if (si < 0) si = 0;
    if (ei > fft.specSize()) ei = fft.specSize();
    // validation
    //if (ei <= 0 || si >= fft.specSize()) return 0f;
    // calculate
    float power = 0f;
    for (int i=si; i<ei; i++) {
      power += bands[i]*sinc_PI(fidx-i);
    }
    return power;
  }
  
  float sinc_PI(float x) {
    float y = 1f;
    if (x != 0) y = sin(PI*x)/(PI*x);
    return y;
  }
}