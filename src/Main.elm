port module Main exposing (main)

import Array exposing (Array)
import Browser
import Debug
import Element
    exposing
        ( Element
        , alignRight
        , centerX
        , column
        , el
        , fill
        , height
        , html
        , minimum
        , none
        , padding
        , paddingXY
        , px
        , rgb
        , rgb255
        , row
        , spacing
        , text
        , width
        )
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input exposing (button)
import Html exposing (Html)
import Json.Decode as D
import Json.Encode as E
import Round
import Svg exposing (Svg, polyline, svg)
import Svg.Attributes as Svg exposing (points, stroke, viewBox)
import Svg.Events as Svg
import Svg.Lazy as Svg
import Tuple exposing (first)



-- outgoing ports


port playBuffer : ( AudioInfo, Float, Float ) -> Cmd msg


port decodeUri : String -> Cmd msg


port saveInterval : ( D.Value, String ) -> Cmd msg



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


type Answer
    = Unconfirmed
    | Yes
    | ConfirmedPositive Float
    | No


type alias Placement =
    { mouseX : Int
    , endSec : Float
    , audioInfo : AudioInfo
    }


type alias Model =
    { uri : String
    , field : D.Value
    , audioInfo : Maybe AudioInfo
    , error : String
    , played : Bool
    , vote : Answer
    , mousePos : Maybe MousePos
    , placement : Maybe Placement
    }


type alias Flags =
    { uri : String
    , field : E.Value
    }


init : Flags -> ( Model, Cmd Msg )
init flags =
    ( { uri = flags.uri
      , field = flags.field
      , audioInfo = Nothing
      , played = False
      , error = ""
      , vote = Unconfirmed
      , mousePos = Nothing
      , placement = Nothing
      }
    , Cmd.batch
        [ decodeUri flags.uri
        ]
    )



-- Subscriptions


subscriptions _ =
    Sub.batch [ audioDecoded AudioDecoded ]



-- Update


type Msg
    = AudioDecoded D.Value
    | PlayInterval AudioInfo MousePos
    | PlayFull
    | Move MousePos
    | Vote Answer
    | Confirm Float
    | Reset
    | Leave


update msg m =
    case msg of
        AudioDecoded val ->
            case D.decodeValue decodeAudioInfo val of
                Ok audioInfo ->
                    ( { m | audioInfo = Just audioInfo }
                    , Cmd.none
                    )

                Err err ->
                    ( { m | error = D.errorToString err }
                    , Cmd.none
                    )

        PlayInterval audioInfo pos ->
            let
                placement =
                    placementFromMousePos audioInfo pos
            in
            ( { m | placement = Just placement }
            , play placement
            )

        PlayFull ->
            ( { m | played = True }
            , case m.audioInfo of
                Just audioInfo ->
                    -- Note: currently limit playback to initial 20 seconds
                    playBuffer ( audioInfo, 0.0, 20.0 )

                _ ->
                    Cmd.none
            )

        Move pos ->
            ( { m | mousePos = Just (clampPos pos) }
            , Cmd.none
            )

        Vote answer ->
            ( { m | vote = answer }
            , if answer == No then
                saveInterval ( m.field, "0" )

              else
                Cmd.none
            )

        Reset ->
            ( { m | vote = Unconfirmed }
            , Cmd.none
            )

        Confirm endsAtSec ->
            ( { m | vote = ConfirmedPositive endsAtSec }
            , Cmd.batch
                [ saveInterval ( m.field, Round.round 2 endsAtSec )
                ]
            )

        Leave ->
            ( { m | mousePos = Nothing }
            , Cmd.none
            )



-- clampedX =
--     clampPos pos |> .mouseX


placementFromMousePos audioInfo mousePos =
    let
        cx =
            clampPos mousePos |> .mouseX
    in
    { mouseX = cx
    , endSec = mouseXToSeconds cx audioInfo
    , audioInfo = audioInfo
    }


play placement =
    let
        end =
            placement.endSec

        -- play 1.2 seconds before end marker
        start =
            max 0 <| end - 1.2
    in
    playBuffer ( placement.audioInfo, start, end - start )



-- View


view model =
    Element.layout [ centerX, width (fill |> minimum 800), height (fill |> minimum 200) ] <|
        Maybe.withDefault (text "(preparing audio)") <|
            Maybe.map (viewAudioInfo model) model.audioInfo


viewAudioInfo : Model -> AudioInfo -> Element Msg
viewAudioInfo model audioInfo =
    column [ centerX, spacing 12 ] <|
        case model.vote of
            Yes ->
                [ el [] <| html <| viewWaveform model.mousePos model.placement audioInfo
                , Maybe.map (.endSec >> Round.round 2 >> (\sec -> el [ width fill, Font.center ] <| text ("Phrase end marked at " ++ sec ++ " seconds"))) model.placement |> Maybe.withDefault none
                , row [ centerX, spacing 12 ]
                    [ case model.placement of
                        Just p ->
                            column []
                                [ greenWhiteButton { onPress = Just (Confirm p.endSec), label = text "Confirm" } ]

                        _ ->
                            Element.none
                    , secondaryButton { onPress = Just Reset, label = text "Undo" }
                    ]
                ]

            No ->
                [ text "No audible key phrase"
                , el [ centerX ] <| secondaryButton { onPress = Just Reset, label = text "Undo" }
                ]

            ConfirmedPositive sec ->
                [ text <| "Key phrase ending after " ++ Round.round 2 sec ++ " seconds"
                , el [ centerX ] <| secondaryButton { onPress = Just Reset, label = text "Undo" }
                ]

            Unconfirmed ->
                [ el [ centerX ] <|
                    greenWhiteButton
                        { onPress = Just PlayFull, label = text "Play ▶" }
                , if model.played then
                    row [ centerX, spacing 12 ]
                        [ greenWhiteButton { onPress = Just <| Vote Yes, label = text "Yes" }
                        , greenWhiteButton { onPress = Just <| Vote No, label = text "No" }
                        ]

                  else
                    none
                ]


viewWaveform : Maybe MousePos -> Maybe Placement -> AudioInfo -> Html Msg
viewWaveform mousePos placement audioInfo =
    let
        linePoints x =
            pToStr (x - 20) 0 ++ " " ++ pToStr x 60 ++ " " ++ pToStr (x - 20) 120

        svgBrack color x =
            polyline [ Svg.fill "none", stroke color, points <| linePoints x ] []
    in
    svg
        [ Svg.width "800"
        , Svg.height "120"
        , viewBox "0 0 800 120"
        , Svg.on "click" (D.map (PlayInterval audioInfo) getMousePos)
        , Svg.on "mousemove" (D.map Move getMousePos)
        , Svg.onMouseOut Leave
        ]
        [ Svg.lazy waveformSvg audioInfo.channelData
        , Maybe.map (.mouseX >> svgBrack "darkred") mousePos |> Maybe.withDefault (Svg.text "")
        , Maybe.map (.mouseX >> svgBrack "green") placement |> Maybe.withDefault (Svg.text "")
        ]


type alias MousePos =
    { mouseX : Int
    , mouseY : Int
    }


getMousePos : D.Decoder MousePos
getMousePos =
    D.map2 MousePos
        (D.at [ "offsetX" ] D.int)
        (D.at [ "offsetY" ] D.int)


pToStr x y =
    String.fromInt (100 + x) ++ "," ++ String.fromInt y


sampleToString : Int -> Int -> Int -> Float -> String
sampleToString targetWidth totalLen i v =
    pToStr
        (floor (toFloat targetWidth * toFloat i / toFloat totalLen))
        (floor (60 + (60 * 3 * v)))


waveformSvg : Array Float -> Svg Msg
waveformSvg data =
    polyline [ Svg.fill "none", stroke "blue", points <| waveformToVertices data ] []


waveformToVertices : Array Float -> String
waveformToVertices data =
    -- TODO subsample
    let
        w =
            600

        points =
            Array.indexedMap
                (\i v ->
                    sampleToString w (Array.length data) i v ++ " "
                )
                data
    in
    Array.foldr String.append "" points


greenWhiteButton =
    button
        [ Background.color (rgb255 91 183 91)
        , Border.color (rgb255 204 204 204)
        , Border.rounded 4
        , Border.width 1
        , Border.solid
        , Font.color (rgb255 255 255 255)
        , paddingXY 16 8
        ]


secondaryButton =
    button
        [ Background.color (rgb255 0 0x6D 0xCC)
        , Border.color (rgb255 204 204 204)
        , Border.rounded 4
        , Border.width 1
        , Border.solid
        , Font.color (rgb255 255 255 255)
        , paddingXY 16 8
        ]


main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


defaultFlags =
    { uri = "reactor sample"
    , field = E.null
    }


reactor =
    Browser.sandbox
        { init = first <| init defaultFlags
        , update = \msg m -> first <| update msg m
        , view = view
        }


clamp ( low, high ) x =
    max low <| min x high


clampPos pos =
    { pos | mouseX = clamp ( 1, 600 ) <| pos.mouseX - 100 }


mouseXToSeconds : Int -> AudioInfo -> Float
mouseXToSeconds x audioBuffer =
    (toFloat (audioBuffer.length * x) / 600.0) / audioBuffer.sampleRate
