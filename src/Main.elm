port module Main exposing (main)

import Array exposing (Array)
import Browser
import Debug
import Element exposing (Element, alignRight, column, el, html, rgb, row, text)
import Element.Background as Background
import Element.Border as Border
import Element.Input exposing (button)
import Html exposing (Html)
import Json.Decode as D
import Json.Encode as E
import Svg exposing (Svg, polyline, svg)
import Svg.Attributes as Svg exposing (fill, points, stroke, viewBox)
import Svg.Events as Svg
import Svg.Lazy as Svg
import Tuple exposing (first)



-- outgoing ports


port playBuffer : ( AudioInfo, Float, Float ) -> Cmd msg


port decodeUri : String -> Cmd msg



-- Incoming ports


port audioDecoded : (D.Value -> msg) -> Sub msg


type alias AudioInfo =
    { channelData : Array Float
    , buffer : D.Value
    , sampleRate : Float
    , length : Int
    }


decodeAudioInfo =
    D.map4 AudioInfo
        (D.field "channelData" (D.array D.float))
        (D.field "buffer" D.value)
        (D.field "sampleRate" D.float)
        (D.field "length" D.int)


type alias Model =
    { uri : String
    , audioInfo : Maybe AudioInfo
    , error : String
    , motion : D.Value
    , pos : Pos
    , confirmedX : Maybe Int
    }


init : String -> ( Model, Cmd Msg )
init waveUri =
    ( { uri = waveUri
      , audioInfo = Nothing
      , error = ""
      , motion = E.null
      , pos = Pos 600 0
      , confirmedX = Nothing
      }
    , Cmd.batch
        [ decodeUri waveUri
        ]
    )



-- Subscriptions


subscriptions _ =
    Sub.batch [ audioDecoded AudioDecoded ]



-- Update


type Msg
    = AudioDecoded D.Value
    | PlayInterval
    | PlayFull
    | Moving D.Value
    | Move Pos


update msg m =
    case msg of
        AudioDecoded val ->
            case D.decodeValue decodeAudioInfo val of
                Ok audioInfo ->
                    ( { m | audioInfo = Just audioInfo }
                    , Cmd.none
                      -- playBuffer ( audioInfo, 0.5, 1.0 )
                    )

                Err err ->
                    ( { m | error = D.errorToString err }
                    , Cmd.none
                    )

        PlayInterval ->
            ( { m | confirmedX = Just m.pos.x }
            , case m.audioInfo of
                Just audioBuffer ->
                    let
                        end =
                            posInBuffer m.pos.x audioBuffer

                        start =
                            max 0 <| end - 1.2
                    in
                    playBuffer ( audioBuffer, start, end - start )

                -- TODO play from user indicated inverval
                _ ->
                    Cmd.none
            )

        PlayFull ->
            ( m
            , case m.audioInfo of
                Just audioBuffer ->
                    -- Note: currently limit playback to initial 20 seconds
                    playBuffer ( audioBuffer, 0.0, 20.0 )

                _ ->
                    Cmd.none
            )

        Move p ->
            ( { m | pos = p }, Cmd.none )

        Moving v ->
            ( { m | motion = v }, Cmd.none )


posInBuffer : Int -> AudioInfo -> Float
posInBuffer x audioBuffer =
    (toFloat x / 600.0) * toFloat audioBuffer.length / audioBuffer.sampleRate



-- View


view model =
    Element.layout [] <|
        Element.column []
            [ Maybe.map (viewAudioInfo model.pos.x model.confirmedX) model.audioInfo |> Maybe.withDefault (text "...")
            ]


viewAudioInfo : Int -> Maybe Int -> AudioInfo -> Element Msg
viewAudioInfo x confirmedX info =
    column []
        [ -- text "Place the red line just past the 'ks' in the utterance. Click to listen"
          html <| viewWaveform x confirmedX info.channelData
        ]


viewWaveform : Int -> Maybe Int -> Array Float -> Html Msg
viewWaveform lineX confirmedX data =
    let
        pToStr x y =
            String.fromInt x ++ "," ++ String.fromInt y

        linePoints x =
            pToStr (x - 20) 0 ++ " " ++ pToStr x 60 ++ " " ++ pToStr (x - 20) 120

        svgBrack color x =
            polyline [ fill "none", stroke color, points <| linePoints x ] []
    in
    svg
        [ Svg.width "600"
        , Svg.height "120"
        , viewBox "0 0 600 120"
        , Svg.on "click" (D.succeed PlayInterval)
        , Svg.on "mousemove" (D.map Move getClickPos)
        ]
        [ Svg.lazy waveformSvg data
        , svgBrack "darkred" lineX
        , Maybe.map (svgBrack "green") confirmedX |> Maybe.withDefault (Svg.text "")
        ]


type alias Pos =
    { x : Int
    , y : Int
    }


getClickPos : D.Decoder Pos
getClickPos =
    D.map2 Pos
        (D.at [ "offsetX" ] D.int)
        (D.at [ "offsetY" ] D.int)


waveformSvg : Array Float -> Svg Msg
waveformSvg data =
    polyline [ fill "none", stroke "blue", points <| waveformToVertices data ] []


waveformToVertices : Array Float -> String
waveformToVertices data =
    -- TODO subsample
    let
        w =
            600

        points =
            Array.indexedMap
                (\i v ->
                    sampleToString w (toFloat (Array.length data)) i v ++ " "
                )
                data
    in
    Array.foldr String.append "" points


sampleToString targetWidth totalLen i v =
    String.fromFloat (targetWidth * toFloat i / totalLen)
        ++ ","
        ++ String.fromFloat (60 + (60 * 3 * v))


main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


defaultFlags =
    "reactor sample"


reactor =
    Browser.sandbox
        { init = first <| init defaultFlags
        , update = \msg m -> first <| update msg m
        , view = view
        }
