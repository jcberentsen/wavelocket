port module Main exposing (Model, Msg, defaultFlags, init, main, playUri, reactor, subscriptions, update, view)

import Browser
import Element exposing (Element, alignRight, el, rgb, row, text)
import Element.Background as Background
import Element.Border as Border
import Json.Encode as E
import Tuple exposing (first)



-- outgoing ports


port playUri : ( String, Float, Float ) -> Cmd msg


port decodeUri : String -> Cmd msg



-- incoming ports


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


init : Model -> ( Model, Cmd Msg )
init waveUri =
    ( { waveUri = waveUri, decodedAudio = E.null }
    , Cmd.batch [ playUri ( waveUri, 0.5, 1.0 ) ]
    )



-- Subscriptions


subscriptions _ =
    Sub.batch [ audioDecoded AudioDecoded ]



-- Update


type alias Msg =
    AudioDecoded E.Value


update msg m =
    case msg of
        AudioDecoded val ->
            ( { m | decodedAudio = val }
            , Cmd.none
            )



-- View


view model =
    Element.layout [] <| text <| "wavelocket: " ++ model.waveUri ++ toString model.decodedAudio
