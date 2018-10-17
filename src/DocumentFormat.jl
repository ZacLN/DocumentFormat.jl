module DocumentFormat
using CSTParser
import CSTParser.Tokenize.Tokens

struct Edit{T}
    loc::T
    text::String
end

mutable struct State{T}
    offset::Int
    edits::T
end

function format(text)
    state = State(0, Edit[])
    x = CSTParser.parse(text, true)
    pass(x, state, operator_pass)
    state.offset = 0
    pass(x, state, tuple_pass)
    state.offset = 0
    pass(x, state, curly_pass)
    state.offset = 0
    pass(x, state, call_pass)
    sort!(state.edits, lt = (a,b) -> first(a.loc) < first(b.loc), rev = true)
    for i = 1:length(state.edits)
        text = apply(text, state.edits[i])
    end
    text = indents(text)
    return text
end

function pass(x::CSTParser.LeafNode, state, f = (x,edits)->nothing)
    state.offset += x.fullspan
end

function pass(x, state, f = (x,state)->nothing)
    f(x, state)
    for a in x
        pass(a, state, f)
    end
    state
end



function get_last_char_index(s)
    len = lastindex(s)
    pos = len > 5 ? len - 5 : 1
    try
        while true
            try; s[pos]; catch StringIndexError; pos += 1; continue; end
            break
        end
    catch BoundsError
        error("A UTF-8 char longer than 5 bytes was encountered, which is not supported currently.")
    end
    while true
        if (nextpos = nextind(s, pos)) > len ; break; end
        pos = nextpos
    end
    pos
end

function ensure_single_space_after(x, state, offset)
    if x.fullspan == last(x.span)
        if x isa CSTParser.OPERATOR
            if length(x.span) > 1 && length(String(Expr(x))) == 1
                push!(state.edits, Edit(offset + 1, " "))
            else
                push!(state.edits, Edit(offset + x.fullspan, " "))
            end
        else
            last_char_index=isdefined(x,:val) ? get_last_char_index(x.val) : x.fullspan
            push!(state.edits, Edit(offset + last_char_index, " "))
        end
    end
end

function ensure_no_space_after(x, state, offset)
    if x.fullspan != last(x.span)
        push!(state.edits, Edit(offset .+(last(x.span)+1:x.fullspan), ""))
    end
end

function apply(text, edit::Edit{Int})
    string(text[1:edit.loc], edit.text, text[nextind(text, edit.loc):end])
end
function apply(text, edit::Edit{UnitRange{Int}})
    string(text[1:prevind(text, first(edit.loc))], edit.text, text[nextind(text, last(edit.loc)):end])
end
include("passes.jl")
include("indents.jl")
end
