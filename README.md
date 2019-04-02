# PitchShifter
A Realtime Pitch Shift Effector with Processing and Minim.

This effect algorithm is FFT and simple interpolated shifting frequency.
So it is low quarity, very slowly, and not useful.
If you use this code, you should improve the algorithm.

## Environment
- Processing 2 or 3
- Minim (if your Processing is version 2)

## Control
- File
  * 'O' key : Open a file
- Player
  * Return/Enter key : Pause or Play
  * Left key : Seek backward for 2s
  * Right key : Seek forward for 1s
- Pitch Effect
  * Mouse Vertical Drag : Amplitude control
  * Mouse Horizontal Drag : Pitch control
  * 'A' key : Switch auto gain control mode
  * 'P' key : Change input mode to Pitch
  * 'G' key : Change input mode to Gain
  * 'Z' key : Switch input mode
  * Numeric/'.' key : Input new Pitch/Gain value
  * BS key : Delete last number or period.

## Author
@sabamotto
