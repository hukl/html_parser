-module(html_parser).

-export([]).


%% API
-export([parse/1]).
-export([
    tags_by_name/2,
    first_tag/2,
    get_children_tag_names/1,
    tag_with_classes/2,
    tag_attributes/1,
    tag_children/1
]).

-import(tokenizer, [tokenize/1]).

-include("include/html_parser.hrl").

-spec parse(binary()) -> list().
parse(Input) ->
  build_tree(tokenize(Input)).

-spec build_tree([html_term(),...]) -> list().
build_tree(Stack) ->
  {Tree, _} = build_tree(Stack, []),
  Tree.

-spec build_tree([html_term(),...], list()) -> list().
build_tree([], Tree) ->
  {Tree, []};

build_tree([_Term = {TagName, opening_tag, Attributes}, _Term1 = {TagName1, closing_tag} | T],  Tree) when TagName =:= TagName1 ->
    Tag = #tag{name=TagName, attributes = Attributes},
    Tree1 = Tree ++ [Tag],
    build_tree(T, Tree1);

build_tree([_Term = {_TagName, closing_tag} | T], Tree) ->
    {Tree, T};

build_tree([_Term = {TagName, opening_tag, Attributes} | T], Tree) ->
    {Children, Remainder} = build_tree(T, []),
    Tag = #tag{name=TagName, children = Children, attributes = Attributes},
    Tree1 = Tree ++ [Tag],
    build_tree(Remainder, Tree1);

build_tree([_Term = {TagName, singleton_tag, Attributes}| T], Tree) ->
    Tag = #tag{name=TagName, attributes = Attributes},
    Tree1 = Tree ++ [Tag],
    build_tree(T, Tree1);

build_tree([_Term = {comments, Comments}| T], Tree) ->
    Tree1 = Tree ++ [{comments, Comments}],
    build_tree(T, Tree1);

build_tree([_Term = {text, Text}| T], Tree) ->
    Tree1 = Tree ++ [{text, Text}],
    build_tree(T, Tree1).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Tree Lookup
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

tags_by_name(Tag, Tree) ->
  Tags = tags_by_name(Tag, Tree, []),
  reply(Tags).


tags_by_name(_Tag, _Tree = [], Acc) ->
  Acc;

tags_by_name(Tag, [H|T], Acc) when is_record(H, tag) ->
  Acc1 =
    case Tag =:= tag_name(H) of
      true ->
        Acc ++ [H];
      false ->
        Acc
    end,
  Acc2 = Acc1 ++ tags_by_name(Tag, tag_children(H), []),
  tags_by_name(Tag, T, Acc2);

tags_by_name(Tag, [_H|T], Acc) ->
  tags_by_name(Tag, T, Acc).


first_tag(Tag, [H|_T]) when element(2, H) =:= Tag ->
  {ok, H};

first_tag(_Tag, []) ->
  {not_found, {}};

first_tag(Tag, [H|T]) when length(H#tag.children) > 0 ->
  case first_tag(Tag, H#tag.children) of
    {not_found,_} ->
      first_tag(Tag,T);
    Result ->
      Result
  end;

first_tag(Tag, [_H|T]) ->
  first_tag(Tag, T).


get_children_tag_names({ok, Tag}) ->
  get_children_tag_names(Tag);

get_children_tag_names(Tag) when is_record(Tag, tag) ->
  lists:foldl(fun get_tag_name/2, [], Tag#tag.children).


get_tag_name({tag, Name, _,_}, Acc) ->
  Acc1 = Acc ++ [Name],
  Acc1;

get_tag_name(_, Acc) ->
  Acc.

tag_with_classes(Classes= [], _Tree) ->
  reply(Classes);

tag_with_classes(Classes, Tree) ->
  {Tags, _} = tag_with_classes(Tree, Classes, []),
  reply(Tags).


tag_with_classes(_Tree = [], _Classes, Acc) ->
  {Acc, []};

tag_with_classes(_Tree = [H|T], Classes, Acc) when is_record(H, tag) ->
  Acc1 = add_tag(H, Classes, Acc),
  Children = tag_children(H),
  {Acc2, _Remainder} =
    case length(Children) > 0 of
      true ->
        tag_with_classes(Children, Classes, Acc1);
      false ->
        {Acc1, T}
    end,
  tag_with_classes(T, Classes, Acc2);

tag_with_classes(_Tree = [_H|T], Classes, Acc) ->
  tag_with_classes(T, Classes, Acc).


reply([])   ->
  {not_found, []};

reply(List) ->
  {ok, List}.


add_tag(Tag, Classes, Acc) ->
  Attributes = tag_attributes(Tag),
  IsMatch =
    case lists:keysearch(<<"class">>,1,Attributes) of
      {value, {_,TagClasses}} ->
        F = fun(P) -> lists:any(fun(P1) -> P1 =:= P end, Classes) end,
        length(Classes) =:= length(lists:takewhile(F, TagClasses));
      false ->
        false
    end,
  case IsMatch of
    true ->
      Acc ++ [Tag];
    false ->
      Acc
  end.


tag_name(Tag) when is_record(Tag, tag) ->
  Tag#tag.name.


tag_children(Tag) when is_record(Tag, tag) ->
  case Tag#tag.children of
    undefined ->
      [];
    List ->
      List
  end.


tag_attributes(Tag) when is_record(Tag, tag) ->
  Tag#tag.attributes.

