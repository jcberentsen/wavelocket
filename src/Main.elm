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
import Svg exposing (Svg, polyline, svg)
import Svg.Attributes as Svg exposing (points, stroke, viewBox)
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


type Answer
    = Yes
    | No


type alias Model =
    { uri : String
    , audioInfo : Maybe AudioInfo
    , error : String
    , played : Bool
    , vote : Maybe Answer
    , mousePos : Maybe Pos
    , confirmedX : Maybe Int
    }


init : String -> ( Model, Cmd Msg )
init waveUri =
    ( { uri = waveUri
      , audioInfo = Nothing
      , played = False
      , error = ""
      , vote = Nothing
      , mousePos = Nothing
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
    | PlayInterval Pos
    | PlayFull
    | Move Pos
    | Vote Answer
    | Confirm
    | Reset
    | Leave


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

        PlayInterval pos ->
            let
                clampedPos =
                    { x = max 1 (min (pos.x - 100) 600), y = pos.y }
            in
            ( { m | confirmedX = Just clampedPos.x }
            , case m.audioInfo of
                Just audioBuffer ->
                    let
                        end =
                            posInBuffer clampedPos.x audioBuffer

                        start =
                            max 0 <| end - 1.2
                    in
                    playBuffer ( audioBuffer, start, end - start )

                -- TODO play from user indicated inverval
                _ ->
                    Cmd.none
            )

        PlayFull ->
            ( { m | played = True }
            , case m.audioInfo of
                Just audioBuffer ->
                    -- Note: currently limit playback to initial 20 seconds
                    playBuffer ( audioBuffer, 0.0, 20.0 )

                _ ->
                    Cmd.none
            )

        Move pos ->
            ( { m | mousePos = Just { x = max 1 (min (pos.x - 100) 600), y = pos.y } }
              -- TODO DRY this
            , Cmd.none
            )

        Vote answer ->
            ( { m | vote = Just answer }
            , Cmd.none
            )

        Reset ->
            ( { m | vote = Nothing }
            , Cmd.none
            )

        Confirm ->
            ( m
            , Cmd.none
            )

        Leave ->
            ( { m | mousePos = Nothing }
            , Cmd.none
            )


posInBuffer : Int -> AudioInfo -> Float
posInBuffer x audioBuffer =
    (toFloat x / 600.0) * toFloat audioBuffer.length / audioBuffer.sampleRate



-- View


view model =
    Element.layout [ width (fill |> minimum 800), height (fill |> minimum 200) ] <|
        Maybe.withDefault (text "...") <|
            Maybe.map (viewAudioInfo model) model.audioInfo


viewAudioInfo : Model -> AudioInfo -> Element Msg
viewAudioInfo model info =
    column [ centerX, spacing 12 ] <|
        case model.vote of
            Just Yes ->
                [ el [] <| html <| viewWaveform model.mousePos model.confirmedX info.channelData
                , row [ centerX, spacing 12 ]
                    [ case model.confirmedX of
                        Just _ ->
                            column []
                                [ greenWhiteButton { onPress = Just Confirm, label = text "Confirm" } ]

                        _ ->
                            Element.none
                    , secondaryButton { onPress = Just Reset, label = text "Undo" }
                    ]
                ]

            Just No ->
                [ text "Negative"
                , secondaryButton { onPress = Just Reset, label = text "Undo" }
                ]

            Nothing ->
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


viewWaveform : Maybe Pos -> Maybe Int -> Array Float -> Html Msg
viewWaveform mousePos confirmedX data =
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
        , Svg.on "click" (D.map PlayInterval getClickPos)
        , Svg.on "mousemove" (D.map Move getClickPos)
        , Svg.onMouseOut Leave
        ]
        [ Svg.lazy waveformSvg data
        , Maybe.map (.x >> svgBrack "darkred") mousePos |> Maybe.withDefault (Svg.text "") -- Svg.empty?
        , Maybe.map (svgBrack "green") confirmedX |> Maybe.withDefault (Svg.text "")
        ]


type alias Pos =
    { x : Int
    , y : Int
    }


pToStr x y =
    String.fromInt (100 + x) ++ "," ++ String.fromInt y


sampleToString : Int -> Int -> Int -> Float -> String
sampleToString targetWidth totalLen i v =
    pToStr
        (floor (toFloat targetWidth * toFloat i / toFloat totalLen))
        (floor (60 + (60 * 3 * v)))


getClickPos : D.Decoder Pos
getClickPos =
    D.map2 Pos
        (D.at [ "offsetX" ] D.int)
        (D.at [ "offsetY" ] D.int)


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
    "reactor sample"


reactor =
    Browser.sandbox
        { init = first <| init defaultFlags
        , update = \msg m -> first <| update msg m
        , view = view
        }
