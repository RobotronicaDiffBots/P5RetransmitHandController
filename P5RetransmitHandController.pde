// For reading bytes from the controller and passing them on to the 
// Applause bots. 

import processing.serial.*;


int xbeeControllerPort = 8;
Serial xbeeController;

int xbeeExplorerPort = 9;
Serial xbeeExplorer;

int baudRate = 57600;
byte controllerSeqno = 0;
byte transmitSeqno = 0;

byte[] inBuffer = new byte[10];
byte[] lastInBuffer = new byte[10];
byte[] msgBuffer = new byte[10];
byte[] lastMsgBuffer = new byte[10];

ArrayList<byte[]> outbox = new ArrayList<byte[]>();

int msgIdx = 0;

int msgLength;

void setup() {

  printArray(Serial.list());

  xbeeController = new Serial(this, Serial.list()[xbeeControllerPort], baudRate);
  xbeeController.buffer(10);

  xbeeExplorer = new Serial(this, Serial.list()[xbeeExplorerPort], baudRate);
  xbeeExplorer.buffer(10);
}

void draw() {
  //println(byte(0xAA) + "," + byte(0x55));

  while (outbox.size () > 0) {
    processMsg(outbox.remove(0));
  }
}

// Format of the message
// [0] 0xAA
// [1] 0x55
// [2] rId byte(-6) == all robots.
// [3] type: 1 = manual control, 2 = auto control (for spins etc.)
// [4] d1:     (velocity of left wheel. 100 = still, < 100 = forward)
// [5] d2:     (velocity of right wheel. 100 = still, < 100 = forward)
// [6] d3:
// [7] d4:     (includes ID of button pushed. From L-R these are 1,2,4,8(L-shoulder),16,32,64,-128(R-shoulder)
// [8] seqno:  (just checks that this seqno != seqno of previous).
// [9] crc:
void serialEvent(Serial whichPort) {
  try {
    if (whichPort == xbeeController) {

      whichPort.readBytes(inBuffer);

      //  println("");
      //  println("inBuffer");
      //  printBuffer(inBuffer);

      // Get the index of 0xAA in the buffer. This marks the start of the message.
      int startIdx = 0;
      while (startIdx < inBuffer.length && inBuffer[startIdx] != byte (0xAA)) {
        msgBuffer[msgIdx] = inBuffer[startIdx];

        startIdx += 1;
        msgIdx = (msgIdx + 1) % inBuffer.length;
      }

      // We should now have a complete message in msgBuffer
      outbox.add(msgBuffer);

      // Start building the next message.
      msgIdx = 0;

      // Now build up the first part of the message (which we fill finish on next pass through).
      for (int i = startIdx; i < inBuffer.length; i++) {
        msgBuffer[msgIdx] = inBuffer[i];
        msgIdx = (msgIdx + 1) % inBuffer.length;
      }
    }
  }
  catch(RuntimeException e) {
    e.printStackTrace();
  }
}

// Process a message received from the hand controller. 
// For now I will just print it to serial.
void processMsg(byte[] msg) {
  if (!checkValidMsg(msg)) {
    //    println("invalid message");
  } else {
    printMsg(msg);
    sendMsg(msg);
  }
}  

void printMsg(byte[] msg) {
  for (int i = 0; i < msg.length; i++) {
    print(int(msg[i]) + ", ");
  }
  println();
}

boolean checkValidMsg(byte[] msg) {
  // Check the first two bytes of the message. They should be 170, 85
  if (msg[0] != byte(170) || msg[1] != byte(85)) {
    println("invalid msg: wrong headers");
    return false;
  }

  // Calculate a crc for the message. This should match the last byte.
  byte crc = 0;
  for (int i = 0; i < msg.length - 1; i++) {
    crc ^= msg[i];
  }

  // If it does not match, then something is wrong with the message.
  if (crc != msg[msg.length - 1]) {
    println("invalid msg: bad crc");
    return false;
  }

  // TODO - check that the sequence number does not match the last one we received.
  //        this is to guard against duplicate messages being sent.

  if (msg[msg.length - 2] == controllerSeqno) {
    println("invalid msg: duplicate seqno");
    return false;
  }
  controllerSeqno = msg[msg.length - 2];

  // ...otherwise, the message is valid.
  return true;
}

void sendMsg(byte[] oldMsg) {
  
  
  // type, byte d1, byte d2, byte d3, byte d4) {
  transmitSeqno++;

  byte[] newMsg = new byte[oldMsg.length];
  arrayCopy(oldMsg, newMsg);

  //  byte[] msg = {byte(170), byte(85), rId, type, d1, d2, d3, d4, seqno, 0};

  newMsg[newMsg.length - 2] = transmitSeqno;

  // Calculate a new crc for the message. This will be included as the last byte.
  byte crc = 0;
  for (int i = 0; i < newMsg.length - 1; i++) {
    crc ^= newMsg[i];
  }
  newMsg[newMsg.length - 1] = crc;

  xbeeExplorer.write(newMsg);
}

