module Main exposing (Msg, init, main, subscriptions, update, view)

import Browser
import Element exposing (Element, alignRight, el, rgb, row, text)
import Element.Background as Background
import Element.Border as Border


main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
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
