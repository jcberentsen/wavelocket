function once(fn, context) {
    var result;

    return function() {
        if(fn) {
            result = fn.apply(context || this, arguments);
            fn = null;
        }
        return result;
    };
}

var audioInput;

var connectAudioOnce = once(function () {
  var audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  return audioCtx;
});

function onError() {
    console.log("Error loading audio")
}

function withLoadSound(url, callback) {
  audioContext= connectAudioOnce();

  var request = new XMLHttpRequest();
  request.open('GET', url, true);
  request.responseType = 'arraybuffer';

  // Decode asynchronously
  request.onload = function() {
    audioContext.decodeAudioData(request.response, function(buffer) {
        callback(buffer);
    }, onError);
  }
  request.send();
}

function doPlayUri(audioUri, startSec, lenSec) {
    withLoadSound(audioUri, function(buffer) {
        playBuffer(buffer, startSec, lenSec);
    });
}

function playBuffer(buffer, startSec, lenSec) {
    audioCtx = connectAudioOnce();

    var source = audioCtx.createBufferSource();
    source.connect(audioCtx.destination);
    start = Math.min( (startSec * buffer.sampleRate), buffer.length);
    len = Math.max( ( start + lenSec * buffer.sampleRate ), buffer.length);

    var arrayBuffer = audioCtx.createBuffer(1, len, buffer.sampleRate);
    fillBuffer(arrayBuffer, start, len, buffer);

    source.buffer = arrayBuffer;
    source.start();
}

function fillBuffer(buf, start, len, fromBuffer)
{
  var nowBuffering = buf.getChannelData(0);
  for (var i = 0; i < len; i++) {
    // audio needs to be in [-1.0; 1.0]
    nowBuffering[i] = fromBuffer.getChannelData(0)[start + i];
  }
}

function registerPorts(app)
{
    var play = function(arg) { doPlayUri(arg[0], arg[1], arg[2]); };
    app.ports.playUri.subscribe(play);
}

