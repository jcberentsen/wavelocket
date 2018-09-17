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

function doPlayUri(audioUri, start, len) {
    withLoadSound(audioUri, function(buffer) {
        playBuffer(buffer, start, len);
    });
}

function playBuffer(buffer, start, len) {
    audioCtx = connectAudioOnce();

    var source = audioCtx.createBufferSource();
    source.connect(audioCtx.destination);

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
    nowBuffering[i] = fromBuffer.getChannelData(0)[start + i]; //  / 16383
  }
}


// function doPlay(waveData, start, len) {
//     console.log("len = " + len);
//     if (len === 0) return;
//     audioCtx = connectAudioOnce();
//     var source = audioCtx.createBufferSource();
//     source.connect(audioCtx.destination);
//     var sampleRate = waveData.waveRate

//     var arrayBuffer = audioCtx.createBuffer(1, len, sampleRate);
//     fillBuffer(arrayBuffer, start, len, waveData);
//     source.buffer = arrayBuffer;
//     source.start();
// }

function registerPorts(app)
{
    var play = function(arg) { doPlayUri(arg[0], arg[1], arg[2]); };
    app.ports.playUri.subscribe(play);
}

// var mediaRecorder;
// var customRecorder;

// function startRecording(recordPort)
// {
//     navigator.getUserMedia = (navigator.getUserMedia ||
//                               navigator.webkitGetUserMedia ||
//                               navigator.mozGetUserMedia ||
//                               navigator.msGetUserMedia);

//     audioCtx = connectAudioOnce();

//     if (navigator.getUserMedia) {
// 	console.log('getUserMedia supported.');
// 	navigator.getUserMedia (
//             {
// 		audio: true,
// 		video: false
//             }
// 	    , // Success callback
//             function(stream) {
// 		customRecorder = { recordPort: recordPort };
// 		recordWithScriptProcessor(audioCtx, stream, customRecorder);
// 	    }
//             ,
//             // Error callback
//             function(err) {
// 		console.log("Can't record: The following gUM error occured: " + err);
//             }
// 	);
//     }
//     else
//     	console.log('getUserMedia not supported :(');
// }

// function concatAudioBuffers(sampleRate, chanDataList)
// {
//     if (chanDataList.length === 0) return null;

//     var size = 0;
//     for (var i=0; i < chanDataList.length; i++)
//     {
// 	buf = chanDataList[i];
// 	size += buf.length
//     }

//     var collected = new Float32Array(size);
//     var offset = 0;
//     for (var i=0; i < chanDataList.length; i++)
//     {
//         chanData = chanDataList[i];
// 	collected.set(chanData, offset);
//         console.log("Copying rec data to offset " + offset);
// 	offset += chanData.length;
//     }

//     newAudioBuffer = audioCtx.createBuffer(1, size, sampleRate);
//     newAudioBuffer.copyToChannel(collected, 0, 0);
//     return newAudioBuffer;
// }

// function recordWithScriptProcessor(audioCtx, stream, customRecorder)
// {
//     customRecorder.recordedAudioBuffers = [];
//     var source = audioCtx.createMediaStreamSource(stream);
//     var capture = audioCtx.createScriptProcessor(8192, 1, 1);
//     capture.onaudioprocess = function(audioProcessingEvent) {
// 	    var inputBuffer = audioProcessingEvent.inputBuffer;
//         var channelData = inputBuffer.getChannelData(0);
//         customRecorder.sampleRate = inputBuffer.sampleRate;
// 	    console.log("rec.");
//         console.dir(channelData);
//         copy = new Float32Array(channelData);
// 	    customRecorder.recordedAudioBuffers.push(copy);
//     }

//     customRecorder.stop = function(rate) {
// 	    source.disconnect(capture);
// 	    capture.disconnect(audioCtx.destination);
// 	    console.dir(customRecorder);

// 	    recordedFullAudioBuffer = concatAudioBuffers(customRecorder.sampleRate, customRecorder.recordedAudioBuffers);
// 	    resampleTo(rate, recordedFullAudioBuffer).then(function(resampled){
//             console.log("Resampled recording to " + rate + "Hz");
//             sendAudioBufferToPort(customRecorder.recordPort, rate, resampled);
// 	    });
//     };

//     source.connect(capture);
//     capture.connect(audioCtx.destination);
// }

// function sendAudioBufferToPort(port, rate, audioBuffer)
// {
//     channel = audioBuffer.getChannelData(0);
//     // Copy Float32Array (TypedArray) to normal Array
//     result = [rate, Array.prototype.slice.call(channel)];
//     port.send(result);
// }

// function resampleTo(sps, audioBuffer)
// {
//     length = audioBuffer.length * sps / audioBuffer.sampleRate;
//     ctx = new OfflineAudioContext(1, length, sps);
//     source = ctx.createBufferSource();
//     source.buffer = audioBuffer;
//     source.loop = false;
//     source.connect(ctx.destination);
//     source.start();

//     // start rendering, return the promise
//     return ctx.startRendering();
// }

// function stopRecording(resampleToRate)
// {
//     customRecorder.stop(resampleToRate);
//     console.log("Custom recorder stop: " + customRecorder);
//     console.log("recorder stopped");
// }

// Recording api docs: https://developer.mozilla.org/en-US/docs/Web/API/MediaStreamAudioSourceNode

// Blocker: https://bugs.chromium.org/p/chromium/issues/detail?id=570980
// use case demo with issue: https://plnkr.co/edit/2NQbJkKevo89Yjy20vmH?p=preview
