# Wavelocket

Wavelocket is a small `elm` app for passing judgement on an audio clip.
The user can Accept or Reject the clip.
Accepted clips also needs a second judgement of where the informative part of
the audio ends.

## Compile the Main.elm to javascript

## Requires elm > 0.19
```sh
elm --version
```

```sh
elm make src/Main.elm  --output=publics/wavelocket.js
```

## Test run with elm-reactor

```sh
elm reactor
```
