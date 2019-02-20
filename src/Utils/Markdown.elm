module Utils.Markdown exposing (block)

-- where

import Html
import Markdown


block : String -> Html.Html msg
block raw =
    Markdown.toHtmlWith myOptions [] raw


myOptions : Markdown.Options
myOptions =
    let
        options =
            Markdown.defaultOptions
    in
    { options | defaultHighlighting = Just "elm" }
