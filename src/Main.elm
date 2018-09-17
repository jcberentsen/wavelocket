module Main exposing (Msg, init, main, reactor, subscriptions, update, view)

import Browser
import Element exposing (Element, alignRight, el, rgb, row, text)
import Element.Background as Background
import Element.Border as Border
import Tuple exposing (first)


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
    String


init : Model -> ( Model, Cmd Msg )
init waveUri =
    ( waveUri
    , Cmd.none
    )



-- Subscriptions


subscriptions _ =
    Sub.none



-- Update


type alias Msg =
    ()


update _ m =
    ( m
    , Cmd.none
    )



-- View


view waveUri =
    Element.layout [] <| text <| "wavelocket: " ++ waveUri
