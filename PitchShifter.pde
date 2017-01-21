/**
 * Pitch Shifter
 * copyright(c) 2013 SabaMotto.
 */

import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;

Minim minim;
AudioPlayer song;
FFTEffect effect;
PitchEffect processor;

String nextRate;
int pmode;
boolean autoGain = true;

void setup() {
  size(1024, 640, P3D);
  frameRate(8);
  
  minim = new Minim(this);
  selectSound();
}

void selectSound() {
  if (song != null) song.close();
  song = null; effect = null;
  nextRate = ""; pmode = 0;
  selectInput("Please choose your wav or mp3 audio file", "fileSelected");
}

void fileSelected(File selection) {
  if (selection == null) return;
  String file = selection.getAbsolutePath();
  
  song = minim.loadFile(file,2048*4);
  song.play();
  
  processor = new PitchEffect();
  effect = new FFTEffect(song.bufferSize(),
                         song.sampleRate(),
                         processor);
  effect.setPrecision(3);
  
  song.addEffect(effect);
}

void draw() {
  if (song == null || effect == null) return;
  if (!song.isPlaying()) return;
  
  background(0);
  blendMode(ADD);
  
  // display spectrum
  stroke(0,255,0);
  float fx = log(effect.indexToFreq(1));
  float fwid = log(song.sampleRate()/2)-fx, bx = 0, by;
  by = (-10-log(0.0001f+effect.getPostBand(0)/16f))*16;
  line( 0, height/2, 0, height/2+by );
  for (int i = 1; i < effect.specSize(); i++)
  {
    float y = (-10-log(0.0001f+effect.getPostBand(i)/16f))*16;
    float lx = (log(effect.indexToFreq(i))-fx)/fwid*width;
    line( i, height/2, i, height/2+y );
    line( bx, height/2-by, lx, height/2-y );
    bx = lx; by = y;
  }
  
  // display original spectrum
  stroke(255,0,0);
  fx = log(effect.indexToFreq(1));
  fwid = log(song.sampleRate()/2)-fx;
  bx = 0;
  by = (-10-log(0.0001f+effect.getPreBand(0)/16f))*16;
  line( 0, height/2, 0, height/2+by );
  for (int i = 1; i < effect.orig.length; i++)
  {
    float y = (-10-log(0.0001f+effect.getPreBand(i)/16f))*16;
    float lx = (log(effect.indexToFreq(i))-fx)/fwid*width;
    line( i, height/2, i, height/2+y );
    line( bx, height/2-by, lx, height/2-y );
    bx = lx; by = y;
  }
  
  // display wave
  stroke(0, 0, 255);
  for (int i = 0; i < song.left.size()-1; i++)
  {
    line(i, height/6 + song.mix.get(i)*100, i+1, height/6 + song.mix.get(i+1)*100);
  }
  
  // display information
  noStroke();
  fill(240);
  text(
    "Shift rate: x"+processor.shiftRate+" , "+
    "Gain: x"+processor.gain+(autoGain?" (AUTO)":"")+" | "+
    (pmode == 0 ? "S.R." : "Gain")+
    (nextRate.equals("") ? "" : " x"+nextRate)
    , 8, height-8);
  fill(64);
  if (mousePressed) rect(0,height-8-12, width,height);
  
//  println(effect.freqToIndex(430));
//  println(effect.indexToFreq(effect.freqToIndex(430)));
} 

int startMX, startMY;
float startRate, startGain;
void mousePressed() {
  startMX = mouseX;
  startRate = processor.shiftRate;
  
  startMY = mouseY;
  startGain = processor.gain;
}
void mouseDragged() {
  if (song == null || effect == null) return;
  
  processor.setShiftRate(startRate+0.01f*(mouseX-startMX));
  if (autoGain)
    processor.setGain(startGain-0.003f*(mouseX-startMX));
  else
    processor.setGain(startGain-0.01f*(mouseY-startMY));
}

void keyPressed() {
  // for PitchShift engine
  if (key >= '0' && key <= '9') inputNumber(key-'0');
  else if (key == '.') inputNumber(-1);
  else if (key == 'a' || key == 'A') autoGain = !autoGain;
  else if (key == 'p' || key == 'P') pmode = 0;
  else if (key == 'g' || key == 'G') pmode = 1;
  else if (key == 'z' || key == 'Z') {
    pmode++;
    if (pmode > 1) pmode = 0;
  }
  else if (keyCode == BACKSPACE) inputNumber(-2);
  else if (!nextRate.equals("") && (keyCode == RETURN || keyCode == ENTER)) {
    decideRate(); return;
  }
  
  if (key == 'o' || key == 'O') selectSound();
  else if (keyCode == RETURN || keyCode == ENTER) {
    if (song.isPlaying()) song.pause();
    else song.play();
  } else if (keyCode == LEFT) song.cue(max(0,song.position()-2000));
  else if (keyCode == RIGHT) song.skip(1000);
}

void inputNumber(int num) {
  if (num == -1) { // comma
    if (nextRate.indexOf(".") > -1) return;
    else if (nextRate.equals("")) return;
    nextRate += ".";
  } else if (num == -2) {
    if (nextRate.equals("")) return;
    nextRate = nextRate.substring(0,nextRate.length()-1);
  } else if (num >= 0 && num <= 9) {
    nextRate += ""+num;
  }
}

void decideRate() {
  float num = parseFloat(nextRate);
  if (pmode == 0) processor.setShiftRate(num);
  else if (pmode == 1) processor.setGain(num);
  nextRate = "";
  
  fill(240);
  rect(0,height-8-12, width,height);
}

void stop() {
  if (song != null) song.close();
  minim.stop();
  super.stop();
}