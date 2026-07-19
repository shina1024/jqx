import type { Json } from "./index.js";

export type InferenceFallbackMode = "unknown" | "json";

type InferenceFallbackValue<Mode extends InferenceFallbackMode> = Mode extends "json"
  ? Json
  : unknown;

type TrimLeft<S extends string> = S extends ` ${infer Rest}` ? TrimLeft<Rest> : S;
type TrimRight<S extends string> = S extends `${infer Rest} ` ? TrimRight<Rest> : S;
type Trim<S extends string> = TrimLeft<TrimRight<S>>;

type HasUnsupportedPathToken<S extends string> =
  S extends `${string}${"|" | "," | "(" | ")" | ":" | ";" | "?" | "+" | "-" | "*" | "/" | "=" | "!" | "<" | ">" | "$" | "@" | '"' | "'" | "`" | " " | "\n" | "\r" | "\t"}${string}`
    ? true
    : false;

type ReadFieldToken<
  Path extends string,
  Acc extends string = "",
> = Path extends `${infer Char}${infer Rest}`
  ? Char extends "." | "["
    ? [Acc, `${Char}${Rest}`]
    : ReadFieldToken<Rest, `${Acc}${Char}`>
  : [Acc, ""];

type ArrayElement<Current, Mode extends InferenceFallbackMode> = Current extends null | undefined
  ? InferenceFallbackValue<Mode>
  : Current extends ReadonlyArray<infer Item>
    ? Item
    : InferenceFallbackValue<Mode>;

type AccessFieldSegment<
  Current,
  Field extends string,
  Mode extends InferenceFallbackMode,
> = Current extends null | undefined
  ? InferenceFallbackValue<Mode>
  : Current extends object
    ? Field extends keyof Current
      ? Current[Field]
      : InferenceFallbackValue<Mode>
    : InferenceFallbackValue<Mode>;

type ParseBracketSegment<
  Current,
  Inner extends string,
  Mode extends InferenceFallbackMode,
> = Inner extends ""
  ? ArrayElement<Current, Mode>
  : Inner extends `${number}`
    ? ArrayElement<Current, Mode>
    : InferenceFallbackValue<Mode>;

type ParsePath<Path extends string, Current, Mode extends InferenceFallbackMode> = Path extends ""
  ? Current
  : Path extends `.${infer Rest}`
    ? ParsePath<Rest, Current, Mode>
    : HasUnsupportedPathToken<Path> extends true
      ? InferenceFallbackValue<Mode>
      : Path extends `[${infer Inner}]${infer Rest}`
        ? ParsePath<Rest, ParseBracketSegment<Current, Inner, Mode>, Mode>
        : ReadFieldToken<Path> extends [infer Field, infer Rest]
          ? Field extends string
            ? Rest extends string
              ? Field extends ""
                ? InferenceFallbackValue<Mode>
                : ParsePath<Rest, AccessFieldSegment<Current, Field, Mode>, Mode>
              : InferenceFallbackValue<Mode>
            : InferenceFallbackValue<Mode>
          : InferenceFallbackValue<Mode>;

type ParseFilter<
  Filter extends string,
  Input,
  Mode extends InferenceFallbackMode,
> = Filter extends "."
  ? Input
  : Filter extends `.${infer Path}`
    ? ParsePath<Path, Input, Mode>
    : InferenceFallbackValue<Mode>;

/// Partial inference for jq string filters.
/// Supported subset: `.`, `.foo`, `.foo.bar`, `.[n]`, `.[]`, and their simple combinations.
/// Unsupported syntax falls back to `unknown` (or `Json` when mode is `"json"`).
export type InferJqOutput<
  Input,
  Filter extends string,
  Mode extends InferenceFallbackMode = "unknown",
> = ParseFilter<Trim<Filter>, Input, Mode>;

export interface InferredOptions<
  Filter extends string,
  Input extends Json,
  Mode extends InferenceFallbackMode = "unknown",
> {
  filter: Filter;
  input: Input;
  fallback?: Mode;
}
