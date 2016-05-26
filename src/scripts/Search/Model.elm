module Search.Model exposing (..)

import Docs.Type as Type
import Docs.Package as Package exposing (Package)
import Search.Chunk as Chunk exposing (Chunk)
import Search.Distance as Distance
import String


type alias Model =
    { index : Index
    , filter : Filter
    , result : Result
    }


type alias Index =
    { chunks : List Chunk
    }


type alias Filter =
    { queryString : String
    , query : Maybe Query
    }


type Query
    = Name String
    | Type Type.Type


type alias Result =
    { chunks : List Chunk }


initialModel : Model
initialModel =
    { index = initialIndex
    , filter = initialFilter
    , result = initialResult
    }


initialIndex : Index
initialIndex =
    { chunks = []
    }


initialFilter : Filter
initialFilter =
    { queryString = ""
    , query = Nothing
    }


initialResult : Result
initialResult =
    { chunks = [] }


type Msg
    = BuildIndex (List Package)
    | SetFilter Filter
    | SetFilterQueryFrom String
    | RunFilter


maybeQueryFromString : String -> Maybe Query
maybeQueryFromString string =
    if String.isEmpty string then
        Nothing
    else
        Just
            <| case Type.parse string of
                Ok tipe ->
                    case tipe of
                        Type.Var _ ->
                            Name string

                        _ ->
                            Type tipe

                Err _ ->
                    Name string


buildIndex : List Package -> Index
buildIndex packages =
    { chunks = List.concatMap Chunk.packageChunks packages }


runFilter : Filter -> Index -> Result
runFilter { query } { chunks } =
    let
        resultChunks =
            case query of
                Just filterQuery ->
                    chunks
                        |> distanceByQuery filterQuery
                        |> filterByDistance Distance.lowPenalty
                        |> prioritizeChunks
                        |> List.sortBy (\( d, c ) -> ( d, c.context.name, c.context.moduleName, c.context.packageName ))
                        |> List.map snd

                Nothing ->
                    []
    in
        { chunks = resultChunks }


distanceByQuery : Query -> List Chunk -> List ( Float, Chunk )
distanceByQuery query chunks =
    let
        distance =
            indexedPair
                <| case query of
                    Name name ->
                        Distance.name name

                    Type tipe ->
                        Distance.tipe tipe
    in
        List.map distance chunks


filterByDistance : Float -> List ( Float, Chunk ) -> List ( Float, Chunk )
filterByDistance distance weightedChunks =
    List.filter (fst >> (>=) distance) weightedChunks


prioritizeChunks : List ( Float, Chunk ) -> List ( Float, Chunk )
prioritizeChunks weightedChunks =
    List.map prioritizeChunk weightedChunks


prioritizeChunk : ( Float, Chunk ) -> ( Float, Chunk )
prioritizeChunk ( distance, chunk ) =
    let
        ( userName, packageName ) =
            ( chunk.context.userName, chunk.context.packageName )

        priority =
            Distance.lowPenalty
    in
        if userName == "elm-lang" && packageName == "core" then
            ( distance - priority / 2, chunk )
        else if userName == "elm-lang" then
            ( distance - priority / 3, chunk )
        else if userName == "elm-community" then
            ( distance - priority / 4, chunk )
        else
            ( distance, chunk )


indexedPair : (a -> b) -> a -> ( b, a )
indexedPair f x =
    ( f x, x )
