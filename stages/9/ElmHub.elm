module ElmHub (..) where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Lazy exposing (..)
import Http
import Task exposing (Task)
import Effects exposing (Effects)
import Json.Decode exposing (Decoder, (:=))
import Json.Encode
import Signal exposing (Address)
import Dict exposing (Dict)


searchFeed : String -> Task x Action
searchFeed query =
  let
    -- See https://developer.github.com/v3/search/#example for how to customize!
    url =
      "https://api.github.com/search/repositories?q="
        ++ query
        ++ "+language:elm"

    task =
      Http.get responseDecoder url
        |> Task.map SetResults
  in
    Task.onError task (\_ -> Task.succeed (SetResults []))


responseDecoder : Decoder (List SearchResult)
responseDecoder =
  "items" := Json.Decode.list searchResultDecoder


searchResultDecoder : Decoder SearchResult
searchResultDecoder =
  Json.Decode.object3
    SearchResult
    ("id" := Json.Decode.int)
    ("full_name" := Json.Decode.string)
    ("stargazers_count" := Json.Decode.int)


type alias Model =
  { query : String
  , results : Dict ResultId SearchResult
  }


type alias SearchResult =
  { id : ResultId
  , name : String
  , stars : Int
  }


type alias ResultId =
  Int


initialModel : Model
initialModel =
  { query = "tutorial"
  , results = Dict.empty
  }


view : Address Action -> Model -> Html
view address model =
  div
    [ class "content" ]
    [ header
        []
        [ h1 [] [ text "ElmHub" ]
        , span [ class "tagline" ] [ text "“Like GitHub, but for Elm things.”" ]
        ]
    , input [ class "search-query", onInput address SetQuery, defaultValue model.query ] []
    , button [ class "search-button", onClick address Search ] [ text "Search" ]
    , ul
        [ class "results" ]
        (viewSearchResults address model.results)
    ]


viewSearchResults : Address Action -> Dict ResultId SearchResult -> List Html
viewSearchResults address results =
  results
    |> Dict.values
    |> List.sortBy (.stars >> negate)
    |> filterResults
    |> List.map (viewSearchResult address)


filterResults : List SearchResult -> List SearchResult
filterResults results =
  -- TODO filter out repos with 0 stars
  -- using a case-expression rather than List.filter
  []


onInput address wrap =
  on "input" targetValue (\val -> Signal.message address (wrap val))


defaultValue str =
  property "defaultValue" (Json.Encode.string str)


viewSearchResult : Address Action -> SearchResult -> Html
viewSearchResult address result =
  li
    []
    [ span [ class "star-count" ] [ text (toString result.stars) ]
    , a
        [ href
            ("https://github.com/"
              ++ (Debug.log "Viewing" result.name)
             {- TODO we should no longer see this
             console output when typing in the search box!
             -}
            )
        , target "_blank"
        ]
        [ text result.name ]
    , button
        [ class "hide-result", onClick address (DeleteById result.id) ]
        [ text "X" ]
    ]


type Action
  = Search
  | SetQuery String
  | DeleteById ResultId
  | SetResults (List SearchResult)


update : Action -> Model -> ( Model, Effects Action )
update action model =
  case action of
    Search ->
      ( model, Effects.task (searchFeed model.query) )

    SetQuery query ->
      ( { model | query = query }, Effects.none )

    SetResults results ->
      let
        resultsById : Dict ResultId SearchResult
        resultsById =
          results
            |> List.map (\result -> ( result.id, result ))
            |> Dict.fromList
      in
        ( { model | results = resultsById }, Effects.none )

    DeleteById id ->
      let
        newModel =
          { model | results = Dict.remove id model.results }
      in
        ( newModel, Effects.none )