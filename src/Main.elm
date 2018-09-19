port module Main exposing (main)

import Array exposing (Array)
import Browser
import Debug
import Element exposing (Element, alignRight, el, rgb, row, text)
import Element.Background as Background
import Element.Border as Border
import Json.Decode as D
import Tuple exposing (first)



-- outgoing ports


port playBuffer : ( AudioInfo, Float, Float ) -> Cmd msg



-- port playUri : ( String, Float, Float ) -> Cmd msg


port decodeUri : String -> Cmd msg



-- Incoming ports


port audioDecoded : (D.Value -> msg) -> Sub msg


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



-- Init


type alias Model =
    { uri : String
    , audioInfo : Maybe AudioInfo
    , error : String
    }


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


init : String -> ( Model, Cmd Msg )
init waveUri =
    ( { uri = waveUri
      , audioInfo = Nothing
      , error = ""
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


update msg m =
    case msg of
        AudioDecoded val ->
            case D.decodeValue decodeAudioInfo val of
                Ok audioInfo ->
                    ( { m | audioInfo = Just audioInfo }
                    , playBuffer ( audioInfo, 0.5, 1.0 )
                    )

                Err err ->
                    ( { m | error = D.errorToString err }
                    , Cmd.none
                    )



-- View


view model =
    Element.layout [] <|
        Element.column []
            [ text <| "wavelocket: " ++ String.dropLeft 20 model.uri
            , text <| Debug.toString model.audioInfo
            , text model.error
            ]
