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

function decodeUri(replyTo, audioUri)
{
    withLoadSound(audioUri, function (buffer) {
        console.log("Decoded audio of length: " + buffer.length)
        console.log("Decoded audio rate: " + buffer.sampleRate)
        decodedAudio =
            { channelData: Array.from(buffer.getChannelData(0))
            , buffer: buffer
            , sampleRate: buffer.sampleRate
            , length: buffer.length
            }
        replyTo.send(decodedAudio);
    });
}

function doPlayUri(audioUri, startSec, lenSec) {
    withLoadSound(audioUri, function(buffer) {
        playBuffer(buffer, startSec, lenSec);
    });
}

function playDecodedAudio(decodedAudio, startSec, lenSec) {
    audioCtx = connectAudioOnce();

    var source = audioCtx.createBufferSource();
    source.connect(audioCtx.destination);
    start = Math.min( (startSec * decodedAudio.sampleRate), decodedAudio.length);
    len = Math.min( ( start + lenSec * decodedAudio.sampleRate ), decodedAudio.length - start);

    var arrayBuffer = audioCtx.createBuffer(1, len, decodedAudio.sampleRate);
    fillBuffer(arrayBuffer, start, len, decodedAudio.channelData);

    source.buffer = arrayBuffer;
    source.start();
}

function fillBuffer(buf, start, len, fromChannelData)
{
  var nowBuffering = buf.getChannelData(0);
  for (var i = 0; i < len; i++) {
    // audio needs to be in [-1.0; 1.0]
    nowBuffering[i] = fromChannelData[Math.floor(start + i)];
  }
}

function registerPorts(app)
{
    // var play = function(arg) { doPlayUri(arg[0], arg[1], arg[2]); };
    // app.ports.playUri.subscribe(play);

    var audioDecode = function(arg) { decodeUri(app.ports.audioDecoded, arg); };
    app.ports.decodeUri.subscribe(audioDecode);

    var play = function(arg) { playDecodedAudio(arg[0], arg[1], arg[2]); };
    app.ports.playBuffer.subscribe(play);
}
