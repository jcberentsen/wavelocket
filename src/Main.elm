port module Main exposing (main)

import Browser
import Debug
import Element exposing (Element, alignRight, el, rgb, row, text)
import Element.Background as Background
import Element.Border as Border
import Json.Encode as E
import Tuple exposing (first)



-- outgoing ports


port playBuffer : ( E.Value, Float, Float ) -> Cmd msg



-- port playUri : ( String, Float, Float ) -> Cmd msg


port decodeUri : String -> Cmd msg



-- Incoming ports


port audioDecoded : (E.Value -> msg) -> Sub msg


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
    , decodedAudio : E.Value
    }


init : String -> ( Model, Cmd Msg )
init waveUri =
    ( { uri = waveUri, decodedAudio = E.null }
    , Cmd.batch
        [ decodeUri waveUri
        ]
    )



-- Subscriptions


subscriptions _ =
    Sub.batch [ audioDecoded AudioDecoded ]



-- Update


type Msg
    = AudioDecoded E.Value


update msg m =
    case msg of
        AudioDecoded val ->
            ( { m | decodedAudio = val }
            , playBuffer ( val, 0.5, 1.0 )
            )



-- View


view model =
    Element.layout [] <| text <| "wavelocket: " ++ model.uri ++ Debug.toString model.decodedAudio
