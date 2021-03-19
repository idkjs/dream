(* This file is part of Dream, released under the MIT license. See
   LICENSE.md for details, or visit https://github.com/aantron/dream.

   Copyright 2021 Anton Bachin *)



(** {1 Overview}

    Dream is built on just five types. The first two, [request] and [response],
    are the data types of Dream. Requests contain all the interesting fields
    your application will want to read, and the application will handle requests
    by creating and returning responses:

    {[
      type request
      type response
    ]}

    The next three types are for building up request-handling functions:

    {[
      type handler = request -> response promise
      type middleware = handler -> handler
      type route
    ]}

    {ol
    {li
    Handlers are asynchronous functions from requests to responses. They are
    just bare functions — you can define a handler wherever you need it. Once
    you have a handler, you can pass it to {!Dream.run} to turn it into a
    working HTTP server:

    {[
      let () =
        Dream.run (fun _ ->
          Dream.respond "Hello, world!")
    ]}

    This is a complete Dream program that responds to all requests on
    {{:http://localhost:8080} http://localhost:8080 ↪} with status [200 OK] and
    body [Hello, world!]. The rest of Dream is about defining ever more useful
    handlers.
    }

    {li
    Middlewares are functions that take a handler, and run some code before or
    after the handler runs. The result is a “bigger” handler. Middlewares are
    also just bare functions, so you can also create them immediately:

    {[
      let log_requests inner_handler =
        fun request ->
          Dream.log "Got a request!";
          inner_handler request
    ]}

    This middleware prints a message on every request, before passing the
    request to the rest of the app. You can use it with {!Dream.run}:

    {[
      let () =
        Dream.run
          (log_requests (fun _ ->
            Dream.respond "Hello, world!"))
    ]}
    }

    {li
    Routes are used with {!Dream.router} to select which handler each request
    should go to. They are created with helpers like {!Dream.get} and
    {!Dream.scope}:

    {[
      Dream.router [
        Dream.get "/" home_handler;

        Dream.scope "/admin" [] [
          Dream.get "/" admin_handler;
          Dream.get "/logout" admin_logout_handler;
        ];
      ]
    ]}
    }}

    If you prefer a vaguely “algebraic” take on Dream:

    - Literal handlers are {b atoms}.
    - Middleware is for {b sequential composition} (AND-like).
    - Routes are for {b alternative composition} (OR-like). *)

(** {1 Main types} *)

type request = incoming message
(** HTTP requests, such as [GET /something HTTP/1.1]. *)

and response = outgoing message
(** HTTP responses, such as [200 OK]. *)

and handler = request -> response promise
(** Handlers are asynchronous functions from requests to responses. *)

and middleware = handler -> handler
(** Middlewares are functions that take a handler, and run some code before or
    after — producing a “bigger” handler. This is the main form of {e sequential
    composition} in Dream. *)

and route
(** Routes tell {!Dream.router} which handler to select for each request. This
    is the main form of {e alternative composition} in Dream. Routes are created
    by helpers such as {!Dream.get} and {!Dream.scope}. *)



(** {1 Helper types} *)

and _ message
(** [_ message], read as “any message,” allows {{!common_fields} some functions}
    to take either requests or responses as arguments, because both are defined
    in terms of [_ message]. For example:

    {[
      Dream.has_body : _ message -> bool
    ]}

    Dream only ever creates requests and responses, i.e. only [incoming message]
    and [outgoing message]. You don't have to worry about anything else, such as
    [int message]. [incoming] and [outgoing] are never mentioned again in the
    docs — this section is only to help with interpreting arguments of type
    [_ message], “any message.” *)

and incoming
(** Type parameter for [message] for requests. Has no meaning other than it is
    different from {!outgoing}. *)

and outgoing
(** Type parameter for [message] for responses. Has no meaning other than it is
    different from {!incoming}. *)

and 'a promise = 'a Lwt.t
(** Dream uses {{:https://github.com/ocsigen/lwt} Lwt ↪} for promises and
    asynchronous I/O. *)



(** The only purpose of this submodule is to generate a subpage, so as to move
    helpers and repetitive defintions of seldom-used codes out of the main
    docs. The module is immediately included in the main API. *)
module Method_and_status :
sig

(** {1 Methods} *)

type method_ = [
  | `GET
  | `POST
  | `PUT
  | `DELETE
  | `HEAD
  | `CONNECT
  | `OPTIONS
  | `TRACE
  | `PATCH
  | `Method of string
]
(** HTTP request methods. See
    {{:https://tools.ietf.org/html/rfc7231#section-4.3} RFC 7231 §4.2 ↪},
    {{:https://tools.ietf.org/html/rfc5789#page-2} RFC 5789 §2 ↪}, and
    {{:https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods} MDN ↪}. *)

val method_to_string : method_ -> string
(** Evaluates to a string representation of the given method. For example,
    [`GET] is converted to ["GET"]. *)

val string_to_method : string -> method_
(** Evaluates to the {!method_} corresponding to the given method string. *)

(** {1 Statuses} *)

type informational = [
  | `Continue
  | `Switching_Protocols
]
(** Informational ([1xx]) status codes. See
    {{:https://tools.ietf.org/html/rfc7231#section-6.2} RFC 7231 §6.2 ↪} and
    {{:https://developer.mozilla.org/en-US/docs/Web/HTTP/Status#information_responses}
    MDN ↪}. [101 Switching Protocols] is generated internally by
    {!Dream.websocket}. It is usually not necessary to use it directly. *)

type successful = [
  | `OK
  | `Created
  | `Accepted
  | `Non_Authoritative_Information
  | `No_Content
  | `Reset_Content
  | `Partial_Content
]
(** Successful ([2xx]) status codes. See
    {{:https://tools.ietf.org/html/rfc7231#section-6.3} RFC 7231 §6.3 ↪},
    {{:https://tools.ietf.org/html/rfc7233#section-4.1} RFC 7233 §4.1 ↪} and
    {{:https://developer.mozilla.org/en-US/docs/Web/HTTP/Status#successful_responses}
    MDN ↪}. The most common is [200 OK]. *)

type redirection = [
  | `Multiple_Choices
  | `Moved_Permanently
  | `Found
  | `See_Other
  | `Not_Modified
  | `Temporary_Redirect
  | `Permanent_Redirect
]
(** Redirection ([3xx]) status codes. See
    {{:https://tools.ietf.org/html/rfc7231#section-6.4} RFC 7231 §6.4 ↪} and
    {{:https://tools.ietf.org/html/rfc7538#section-3} RFC 7538 §3 ↪}, and
    {{:https://developer.mozilla.org/en-US/docs/Web/HTTP/Status#redirection_messages}
    MDN ↪}. Use [303 See Other] to direct clients to follow up with a [GET]
    request, especially after a form submission. Use [301 Moved Permanently]
    for permanent redirections. *)

type client_error = [
  | `Bad_Request
  | `Unauthorized
  | `Payment_Required
  | `Forbidden
  | `Not_Found
  | `Method_Not_Allowed
  | `Not_Acceptable
  | `Proxy_Authentication_Required
  | `Request_Timeout
  | `Conflict
  | `Gone
  | `Length_Required
  | `Precondition_Failed
  | `Payload_Too_Large
  | `URI_Too_Long
  | `Unsupported_Media_Type
  | `Range_Not_Satisfiable
  | `Expectation_Failed
  | `Misdirected_Request
  | `Too_Early
  | `Upgrade_Required
  | `Precondition_Required
  | `Too_Many_Requests
  | `Request_Header_Fields_Too_Large
  | `Unavailable_For_Legal_Reasons
]
(** Client error ([4xx]) status codes. The most common are [400 Bad Request],
    [401 Unauthorized], [403 Forbidden], and, of course, [404 Not Found].

    See
    {{:https://developer.mozilla.org/en-US/docs/Web/HTTP/Status#client_error_responses}
    MDN ↪}, and

    - {{:https://tools.ietf.org/html/rfc7231#section-6.5} RFC 7231 §6.5 ↪} for
      most client error status codes.
    - {{:https://tools.ietf.org/html/rfc7233#section-4.4} RFC 7233 §4.4 ↪} for
      [416 Range Not Satisfiable].
    - {{:https://tools.ietf.org/html/rfc7540#section-9.1.2} RFC 7540 §9.1.2 ↪}
      for [421 Misdirected Request].
    - {{:https://tools.ietf.org/html/rfc8470#section-5.2} RFC 8470 §5.2 ↪} for
      [425 Too Early].
    - {{:https://tools.ietf.org/html/rfc6585} RFC 6585 ↪} for
      [428 Precondition Required], [429 Too Many Requests], and [431 Request
      Headers Too Large].
    - {{:https://tools.ietf.org/html/rfc7725} RFC 7725 ↪} for
      [451 Unavailable For Legal Reasons]. *)

type server_error = [
  | `Internal_Server_Error
  | `Not_Implemented
  | `Bad_Gateway
  | `Service_Unavailable
  | `Gateway_Timeout
  | `HTTP_Version_Not_Supported
]
(** Server error ([5xx]) status codes. See
    {{:https://tools.ietf.org/html/rfc7231#section-6.6} RFC 7231 §6.6 ↪} and
    {{:https://developer.mozilla.org/en-US/docs/Web/HTTP/Status#server_error_responses}
    MDN ↪}. The most common of these is [500 Internal Server Error]. *)

type standard_status = [
  | informational
  | successful
  | redirection
  | client_error
  | server_error
]
(** Sum of all the status codes declared above. *)

type status = [
  | standard_status
  | `Status of int
]
(** Status codes, including codes directly represented as integers. See the
    types above for the full list and references. *)

val status_to_string : status -> string
(** Evaluates to a string representation of the given status. For example,
    [`Not_Found] and [`Status 404] are both converted to ["Not Found"]. Numbers
    are used for unknown status codes. For example, [`Status 567] is converted
    to ["567"]. *)

val status_to_reason : status -> string option
(** Converts known status codes to their string representations. Evaluates to
    [None] for unknown status codes. *)

val status_to_int : status -> int
(** Evaluates to the numeric value of the given status code. *)

val int_to_status : int -> status
(** Evaluates to the symbolic representation of the status code with the given
    number. *)

val is_informational : status -> bool
(** Evaluates to [true] if the given status is either from type
    {!Dream.informational}, or is in the range [`Status 100] — [`Status 199]. *)

val is_successful : status -> bool
(** Like {!Dream.is_informational}, but for type {!Dream.successful} and numeric
    codes [2xx]. *)

val is_redirection : status -> bool
(** Like {!Dream.is_informational}, but for type {!Dream.redirection} and
    numeric codes [3xx]. *)

val is_client_error : status -> bool
(** Like {!Dream.is_informational}, but for type {!Dream.client_error} and
    numeric codes [4xx]. *)

val is_server_error : status -> bool
(** Like {!Dream.is_informational}, but for type {!Dream.server_error} and
    numeric codes [5xx]. *)

end

(**/**)
include module type of Method_and_status
(**/**)

type method_ = Method_and_status.method_
(** HTTP request methods. See
    {{:https://tools.ietf.org/html/rfc7231#section-4.3} RFC 7231 §4.2 ↪},
    {{:https://tools.ietf.org/html/rfc5789#page-2} RFC 5789 §2 ↪}, and
    {{:https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods} MDN ↪}. The
    full set of methods is listed on a {{:/method_and_status/index.html}
    separate page}, together with some helpers. *)

type status = Method_and_status.status
(** HTTP response status codes. See
    {{:https://tools.ietf.org/html/rfc7231#section-6} RFC 7231 §6 ↪} and
    {{:https://developer.mozilla.org/en-US/docs/Web/HTTP/Status} MDN ↪}. The
    full set of status codes is listed on a
    {{:/method_and_status/index.html#type-informational} separate page},
    together with some helpers. *)



(** {1:request_fields Request fields} *)

val client : request -> string
(** Client sending the request, for example [127.0.0.1:56001]. *)

val method_ : request -> method_
(** Request method, for example [`GET]. See
    {{:https://tools.ietf.org/html/rfc7231#section-4.3} RFC 7231 §4.2 ↪}. *)

val target : request -> string
(** Request target, for example [/something]. This is the full path as sent by
    the client or proxy. The site root prefix is included. *)

(**/**)
(* These are used for router state at the moment, and I am not sure if there is
   a public use case for them. I may remove them from the API, and have the
   test cases access their internal definitions directly. *)
val prefix : request -> string
val path : request -> string
(**/**)

val version : request -> int * int
(** Protocol version, such as [(1, 1)] for HTTP/1.1 and [(2, 0)] for HTTP/2. *)

val with_client : string -> request -> request
(** Creates a new request from the given one, with the client string
    replaced. *)

val with_method_ : method_ -> request -> request
(** Creates a new request from the given one, with the method replaced. *)

val with_version : int * int -> request -> request
(** Creates a new request from the given one, with the protocol version
    replaced. *)

val cookie : string -> request -> string option
(** Cookies are sent by the client in [Cookie:] headers as [name=value] pairs.
    This function parses those headers, looking for the given [name].

    No decoding is applied to any found [value] — it is returned raw, as sent by
    the client. Cookies are almost always encoded so as to at least escape [=],
    [;], and newline characters, which are significant to the cookie and HTTP
    parsers. If you applied such an encoding when setting the cookie, you have
    to reverse it after calling [Dream.cookie]. See {!Dream.add_set_cookie} for
    recommendations about encodings to use and {!web_formats} for encoders and
    decoders.

    If the request includes multiple cookies with the same name, one is
    returned. *)

val all_cookies : request -> (string * string) list
(** Retrieves all cookies, i.e. all [name=value] in all [Cookie:] headers. As
    with {!Dream.cookie}, no decoding is applied to the values. *)



(** {1:common_fields Common fields} *)

val header : string -> _ message -> string option
(** Retrieves the first header with the given name, if present. *)

val headers : string -> _ message -> string list
(** Retrieves all headers with the given name. *)

val has_header : string -> _ message -> bool
(** Evaluates to [true] if and only if a header with the given name is
    present. *)

val all_headers : _ message -> (string * string) list
(** Retrieves all headers. *)

val add_header : string -> string -> 'a message -> 'a message
(** Creates a new message (request or response) by adding a header with the
    given name and value. Note that, for several header name, HTTP permits
    mutliple headers with the same name. This function therefore does not remove
    any existing headers with the same name. *)

val drop_header : string -> 'a message -> 'a message
(** Creates a new message by removing all headers with the given name. *)

val with_header : string -> string -> 'a message -> 'a message
(** Equivalent to first calling {!Dream.drop_header} and then
    {!Dream.add_header}. Creates a new message by replacing all headers with the
    given name by one header with that name and the given value. *)

val body : _ message -> string Lwt.t
(** Retrieves the body of the given message (request or response), streaming it
    to completion first, if necessary. *)

val has_body : _ message -> bool
(** Evalutes to [true] if the given message either has a body that has been
    streamed and has positive length, or a body that has not been streamed yet.
    This function does not stream the body — it could return [true], and later
    streaming could reveal that the body has length zero. *)

val with_body : ?set_content_length:bool -> string -> 'a message -> 'a message
(** Creates a new message by replacing the body with the given string. *)



(** {1 Responses} *)

val response :
  ?status:status ->
  ?code:int ->
  ?headers:(string * string) list ->
  ?set_content_length:bool ->
  string ->
    response
(** Creates a new response with the given string as body. Use [""] to return an
    empty response, or if you'd like to assign a stream as the response body
    later. [~code] is offered as an alternative to [~status] for specifying the
    status code. If both [~status] and [~code] are given, one is chosen
    arbitrarily. *)

val respond :
  ?status:status ->
  ?code:int ->
  ?headers:(string * string) list ->
  ?set_content_length:bool ->
  string ->
    response Lwt.t
(** Same as {!Dream.val-response}, but immediately uses the new response to
    resolve a new promise, and returns that promise. This helper is especially
    convenient for quickly returning empty error responses, which will be filled
    out later by the top-level error handler. *)

val status : response -> status
(** Response status, for example [`OK]. *)

(* TODO All the optionals for Set-Cookie. *)
(* TODO Or just provide one helper for formatting Set-Cookie and let the user
   use the header calls to actually add the header...? How often do we need to
   set a cookie? *)
val add_set_cookie : string -> string -> response -> response
(** Adds a [Set-Cookie:] header to the given response for setting the cookie
    with the given name to the given value. Does not remove any [Set-Cookie:]
    header that is already present — to do that, use {!Dream.drop_header}. This
    function does not encode the cookie name nor its value. If the values you
    are passing in can have [=], [;], or newlines, ... *)
(* TODO Hints about encodings. *)

(* val reason_override : response -> string option *)
(* If the response was created with [~reason:r], evaluates to [Some r]. *)

(* val version_override : response -> (int * int) option *)
(* If the response was created with [~version:v], evaluates to [Some v]. *)

(* val reason : response -> string *)
(* Response reason string, for example ["OK"]. If the response was created with
    [~reason], that string is returned. Otherwise, it is based on the response
    status. *)



(** {1 Middleware} *)

val identity : middleware
(** Does nothing but call its next handler. This is useful on rare occasions
    when you are forced to provide a middleware, but don't want it to do
    anything. *)

val pipeline : middleware list -> middleware
(** Combines a sequence of middlewares into one, such that these two lines are
    equivalent:

    {[
      Dream.pipeline [mw_1; mw_2; ...; mw_n] @@ handler
      mw_1 @@ mw_2 @@ ... @@ mw_n @@ handler
    ]} *)
(* TODO This code block is highlighted as CSS. Get a better
   highlight.pack.js. *)

val logger : middleware
(** Logs incoming requests, times them, and prints timing information when the
    next handler has returned a response. Time spent logging is included in the
    timings. *)

type form_error = [
  | `Not_form_urlencoded
  | `CSRF_token_invalid
]
(* TODO Distinguish between expired CSRF tokens and other conditions. *)

val form : request -> ((string * string) list, [> form_error ]) result Lwt.t
(* TODO Provide optionals for disabling CSRF checking and CSRF token field
   filtering. *)



(** {1 Routing} *)

val router : route list -> middleware
(** Creates a router from a list of routes. The new router is a middleware which
    calls its next handler if none of its routes match the request. The router
    interprets path components prefixed with [:] as parameters, which can be
    retrieved with {!Dream.crumb}:

    {[
      let () =
        Dream.run
        @@ Dream.router [
          Dream.get "/echo/:word" @@ fun request ->
            Dream.respond (Dream.crumb "word" request);
        ]
        @@ fun _ -> Dream.respond ~status:`Not_Found ""
    ]} *)

val crumb : string -> request -> string
(** Retrieves the given path parameter (“crumb”). If the path parameter is
    missing, [Dream.crumb] treats this as a logic error, and raises an
    exception. *)

val scope : string -> middleware list -> route list -> route
(** Groups routes under a common path prefix and set of scoped middlewares. In
    detail, [Dream.scope path middlewares routes] extends the path of each route
    in [routes] by prefixing each with [path]. If one of [routes] is matched by
    the router while handling a request, the request is passed through
    [middlewares] before being given to the route's handler.

    If you only want to apply middlewares, but not prefix the paths, use [""]
    for the prefix. If you only want to prefix paths, use [[]] for the
    middleware list. *)

val get : string -> handler -> route
(** [Dream.get path handler] is a route that will cause [handler] to be called
    if a request has method [`GET] and path [path]. For example:

    {[
      Dream.get "/home" home_template
    ]} *)

val post : string -> handler -> route
(** Like {!Dream.get}, but the request's method must be [`POST]. *)

val put : string -> handler -> route
(** Like {!Dream.get}, but the request's method must be [`PUT]. *)

val delete : string -> handler -> route
(** Like {!Dream.get}, but the request's method must be [`DELETE]. *)

val head : string -> handler -> route
(** Like {!Dream.get}, but the request's method must be [`HEAD]. *)

val connect : string -> handler -> route
(** Like {!Dream.get}, but the request's method must be [`CONNECT]. *)

val options : string -> handler -> route
(** Like {!Dream.get}, but the request's method must be [`OPTIONS]. *)

val trace : string -> handler -> route
(** Like {!Dream.get}, but the request's method must be [`TRACE]. *)

val patch : string -> handler -> route
(** Like {!Dream.get}, but the request's method must be [`PATCH]. *)



(* TODO Expose typed sessions in the main API? *)
(* TODO Link out to docs of Dream.Session module. Actually, the module needs to
   be included here with its whole API. *)
(* TODO The session manager may need to interact with AJAX in other ways. *)
(** {1 Sessions}

    TODO:

    - Default Dream sessions store [string -> string] dictionaries.
    - There are multiple back ends, storing sessions in memory (for
      development), in a database, stateless in cookies, etc.
    - This is all actually a specialization of Dream's typed sessions, which are
      quite flexible. A user can write their own back ends and use sessions of
      any type. Link to the easy examples. Link to [Dream.Session].
    - Ultimately, if this is not customizable enough, one can write their own
      session back end. If still wishing to use the other parts of Dream that
      depend on sessions, all those parts are configurable by provinding
      callback functions to use any other session setup.
    - What do sessions have? App data (the dictionary), but also a secret key,
      log-friendly id, expiration time.
    - Mention security.
    - Mention pre-sessions. *)

val sessions_in_memory : middleware
(** Stores session data server-side in memory, i.e. without persistence. Passes
    session keys to clients in cookies. Session data is lost when the server
    process exits. This session middleware is suitable for prototyping, because
    it has no persistence or key management requirements. *)

val session : string -> request -> string option
(** Retrieves the value with the given key in the request's session, if the
    value is present. *)

val set_session : string -> string -> request -> unit Lwt.t
(** [Dream.set_session key value request] sets a value in the request's session.
    If there is an existing binding, it is replaced. The data store used by the
    session middleware may immediately commit the value to storage, so this
    function returns a promise. *)

val all_session_values : request -> (string * string) list
(** Retrieves the full session dictionary. *)

val invalidate_session : request -> unit Lwt.t
(** Invalidates the given session, replacing it with a fresh one (a new
    pre-session with an empty dictionary). The session store is likely to update
    storage while creating the new session, so this function returns a
    promise. *)

val session_key : request -> string
(** Evaluates to the request's session's key. This is a secret value that is
    used to identify a client. *)

val session_id : request -> string
(** Evaluates to the request's session's identifier. This value is not secret;
    it is suitable for printing to logs for tracing session lifetime. *)

val session_expires_at : request -> int64
(** Evaluates to the time at which the session will expire. *)



(** {1 WebSockets} *)

(* TODO This signature really needs to be reworked, but it's good enough for a
   proof of concept, and changes should be easy later. *)
val websocket : (string -> string Lwt.t) -> response Lwt.t



(** {1 Logging} *)

val log : ('a, Format.formatter, unit, unit) format4 -> 'a
(** [Dream.log format arguments] formats [arguments] and writes them to the log.
    Disregard the obfuscated type: the first argument, [format], is a format
    string as described in the standard library modules
    {{:http://caml.inria.fr/pub/docs/manual-ocaml/libref/Printf.html#VALfprintf}
    [Printf↪]} and
    {{:http://caml.inria.fr/pub/docs/manual-ocaml/libref/Format.html#VALfprintf}
    [Format↪]}, and the rest of the arguments are determined by the format
    string. For example:

    {[
      Dream.log "Counter is now: %i" counter;
      Dream.log "Client: %s" (Dream.client request);
    ]} *)

type ('a, 'b) conditional_log =
  ((?request:request ->
   ('a, Format.formatter, unit, 'b) format4 -> 'a) -> 'b) ->
    unit
(** See {!Dream.val-error} for usage. This type has to be defined, but its
    definition is largely illegible. *)

val error : ('a, unit) conditional_log
(** Formats a message and writes it to the log at level [`Error]. The inner
    formatting function is called only if the {{!initialize_log} current log
    level} is [`Error] or higher. This scheme is based on the
    {{:https://erratique.ch/software/logs/doc/Logs/index.html} Logs ↪}
    library.

    {[
      Dream.error ~request (fun log -> log "My message, details: %s" details);
    ]}

    Pass the optional argument [~request] to [Dream.error] to help it associate
    the message with a specific request. If not passed, the logging back end
    will try to guess the request. This usually works, but may be inaccurate in
    some cases. *)

val warning : ('a, unit) conditional_log
(** Like {!Dream.val-error}, but the level and threshold are [`Warning]. *)

val info : ('a, unit) conditional_log
(** Like {!Dream.val-error}, but the level and threshold are [`Info]. *)

val debug : ('a, unit) conditional_log
(** Like {!Dream.val-error}, but the level and threshold are [`Debug]. *)

type sub_log = {
  error : 'a. ('a, unit) conditional_log;
  warning : 'a. ('a, unit) conditional_log;
  info : 'a. ('a, unit) conditional_log;
  debug : 'a. ('a, unit) conditional_log;
}
(** Sub-logs. See {!Dream.val-sub_log}. *)

(* TODO How to change levels of individual logs. *)
val sub_log : string -> sub_log
(** Creates a new sub-log with the given name. For example,

    {[
      let log = Dream.sub_log "myapp.ajax"
    ]}

    Creates a logger that can be used like {!Dream.val-error} and the other
    default loggers, but prefixes ["myapp.ajax"] to each log message:

    {[
      log.error ~request (fun log -> log "Validation failed")
    ]} *)

type log_level = [
  | `Error
  | `Warning
  | `Info
  | `Debug
]
(** Log levels, in order from most urgent to least. *)

val initialize_log :
  ?backtraces:bool ->
  ?async_exception_hook:bool ->
  ?level:log_level ->
  ?enable:bool ->
  unit ->
    unit
(** Dream does not initialize its logging back end on program start. This is
    meant to allow a Dream web application to be linked into a larger binary as
    a subcommand, without affecting the runtime of that larger binary in any
    way. Instead, this function, [Dream.initialize_log], is called internally by
    the various Dream loggers (such as {!Dream.log}) the first time they are
    used. You can also call this function explicitly during program
    initialization, before using the loggers, in order to configure the back end
    or disable it completely.

    [~backtraces:true], the default, causes Dream to call
    {{:http://caml.inria.fr/pub/docs/manual-ocaml/libref/Printexc.html#VALrecord_backtrace}
    [Printexc.record_backtrace↪]}, which makes exception backtraces available
    when logging exceptions.

    [~async_exception_hook:true], the default, causes Dream to set
    {{:https://ocsigen.org/lwt/latest/api/Lwt#VALasync_exception_hook}
    [Lwt.async_exception_hook↪]} so as to forward all asynchronous exceptions to
    the logger, and not terminate the process.

    [~level] sets the log level threshould for the entire binary. The default is
    [`Info].

    [~enable:false] disables Dream logging completely. This can help sanitize
    output for testing. *)



(** {1:error_page Error page}

    Dream passes all errors to a single error handler that is immediately above
    the HTTP server layer. This includes:

    - Exceptions raised by the application, and rejected promises.
    - [4xx] and [5xx] responses returned by the application.
    - Protocol-level errors, such as TLS handshake failures and malformed HTTP
      requests.

    This allows you to customize all of your application's error handling in one
    place.

    The easiest way to customize is to call {!Dream.error_template} to create a
    customized version of the default error handler. It will log errors like the
    default handler, and, when a response is possible, it will call your
    template to generate the response. Pass this customized error handler to
    {!Dream.run}.

    The default error handler used by {!Dream.run} uses a default template,
    which generates responses with no body. This prevents leakage of strings, in
    particular unlocalized strings in any natural language.

    If you want full control over error handling, including replacing the
    logging done by the default handler, you can define a {!Dream.error_handler}
    directly, to process all values of type {!Dream.type-error}. *)

type error = {
  condition : [
    | `Response of response
    | `String of string
    | `Exn of exn
  ];
  layer : [
    | `TLS
    | `HTTP
    | `HTTP2
    | `WebSocket
    | `App
  ];
  caused_by : [
    | `Server
    | `Client
  ];
  request : request option;
  response : response option;
  client : string option;
  severity : log_level;
  debug : bool;
  will_send_response : bool;
}
(** Generalized Dream errors.

    [condition] describes the error itself. [`Response] means the error is a
    [4xx] or [5xx] response. [`String] and [`Exn] should be self-explanatory.
    The default error handler logs error strings and exceptions, but does not
    log error responses, because they have been generated explicitly by the
    application. They are typically already noted by {!Dream.logger}, if the
    logger is being used.

    [layer] is [`App] if the error was generated by the application, and one of
    the other values if the error was generated by one of the protocol state
    machines inside {!Dream.run}. For example, in case the client sends an
    HTTP/1.1 request so malformed that it can't be parsed at all, an error with
    [layer = `HTTP] will be generated. The default error handler uses the layer
    to prepend helpful strings to its log messages.

    [caused_by] indicates which side likely caused the error. Server errors
    suggest bugs, and correspond to [5xx] responses. Client errors can be noise,
    or indicate buggy clients or attempted attacks. Client errors correspond to
    [4xx] responses.

    [request] is a request associated with the error, if there is one. A request
    might not be available if, for example, the error is a failure to parse an
    HTTP/1.1 request at all, or perform a TLS handshake. In case of a WebSocket
    error, the request is the client's original request to establish the
    WebSocket connection.

    [response] is either a response that was generated by the application, or a
    suggested response generated by the context where the error occurred. In
    case of a WebSocket error, the response is the application's original
    connection agreement response created by {!Dream.websocket}.

    [client] is the client's address, if available. For example,
    [127.0.0.1:56001].

    [severity] is the likely severity of the error. This is usually [`Error] for
    server errors, and [`Warning] for client errors. The default error handler
    logs the error at level [severity].

    [debug] is [true] if debugging is enabled on the server. If so, the default
    error handler gathers various fields from any available request, formats the
    error condition, and passes the resulting string to the template. The
    default template shows this string in its repsonse, instead of returning a
    response with no body.

    [will_send_response] is [true] in error contexts where Dream will still send
    a response. A typical example is when there is an application exception —
    Dream will still send at least an empty [500 Internal Server Error], if not
    changed by the template. Conversely, in case of a TLS handshake failure,
    there is no client to send an HTTP response to, so no response will be sent.
    In this latter case, the default error handler does not call the template at
    all. *)

type error_handler = error -> response option Lwt.t
(** Error handlers generate responses for errors with
    [will_send_response = true]. They typically also log errors along the way.
    See {!Dream.type-error}. You can define your own freely if you need to —
    it's a bare function.

    If an error handler raises an exception, rejects its result promise, or
    returns [None] when [will_send_response = true] in the error it is handling,
    this is a double fault. Dream prints an emergency message to one of its
    sub-logs, and, depending on the context, does nothing else, sends an empty
    [500 Internal Server Error], or closes a connection.

    The behavior of Dream's built-in error handler is described at
    {!Dream.type-error}. *)

(* TODO Should sanitize template output here or set to text/plain to prevent XSS
   against developer. *)
val error_template :
  (debug_dump:string option -> response -> response Lwt.t) -> error_handler
(** Customizes the default error handler by specifying a template.
    {[
      let my_error_handler =
        Dream.error_template (fun ~debug_dump response ->
          let body =
            match debug_dump with
            | Some string -> string
            | None -> Dream.status_to_string (Dream.status response)
          in

          response
          |> Dream.with_body body
          |> Lwt.return)
    ]}

    [response] is a response suggested by the error context. Its most
    interseting field is {!Dream.val-status}, which is often used in pretty
    templates to generate the main error text.

    If the error is a [4xx] or [5xx] response generated by your application, it
    will be passed to the template in [response]. Otherwise, [response] is
    typically an empty response pre-filled with status [400 Bad Request] or [500
    Internal Server Error], according to whether the underlying error was likely
    caused by the client or the server. The error template will typically
    customize [response]; however, it can also ignore the response and generate
    a fresh one.

    [~debug_dump] will be [Some info] when debugging is enabled for the
    application with [Dream.run ~debug:true]. [info] is a string containing an
    error description, stack trace, request state, and other information.

    Note that not all contexts are capable of using all fields of the response
    returned by the template. For example, some HTTP contexts are hardcoded
    upstream to send either [400 Bad Request] or [500 Internal Server Error],
    regardless of the status returned by the template. They still send the
    template's body, however.

    Raising an exception or rejecting the final promise in the template may
    cause an empty [500 Internal Server Error] to be sent to the client, if the
    context requires it. See {!Dream.error_handler}. *)



(** {1 Variables}

    Dream provides two variable scopes for writing middlewares:

    - Per-message (“local”) variables.
    - Per-server (“global”) variables.

    Variables can be used to implicitly pass values from middlewares to wrapped
    handlers. For example, Dream assigns each request an id, which is stored in
    a “local” (request) variable. {!Dream.request_id} can then be called on that
    request; it internally reads that variable. *)

type 'a local
(** Per-message variable. *)

type 'a global
(** Per-server variable. *)

val new_local : ?debug:('a -> string * string) -> unit -> 'a local
(** Declares a fresh variable of type ['a] in all messages. In each message, the
    variable is initially unset. The optional [~debug] parameter provides a
    function that converts the variable's value to a pair of [key, value]
    strings. This causes the variable to be included in debug info by the
    default error handler when debugging is enabled. *)
(* TODO Provide a way to query the local for its name, which can be used by
   middlewares for generating nicer error messages when a local is not found.
   But then the metadata has to become string * 'a -> string, or it can be
   split into to a separate name and converter to make it even easier to deal
   with. *)

val local : 'a local -> _ message -> 'a option
(** Retrieves the value of the given per-message variable, if it is set. *)

val with_local : 'a local -> 'a -> 'b message -> 'b message
(** Creates a new message by setting or replacing the variable with the given
    value. *)

val new_global : ?debug:('a -> string * string) -> (unit -> 'a) -> 'a global
(** [Dream.new_global initializer] declares a fresh variable of type ['a] in all
    servers. The first time the variable is accessed, [ititializer ()] is called
    to create its initial value.

    Global variables cannot themselves be changed, because the server-wide
    application context is shared between all requests. This means that global
    variables are typically refs or other mutable data structures, such as hash
    tables — as is often the case with regular OCaml globals. *)

val global : 'a global -> request -> 'a
(** Retrieves the value of the given per-server variable. *)



(** {1 HTTP} *)

val run :
  ?interface:string ->
  ?port:int ->
  ?stop:unit Lwt.t ->
  ?debug:bool ->
  ?error_handler:error_handler ->
  ?secret:string ->
  ?prefix:string ->
  ?https:[ `No | `OpenSSL | `OCaml_TLS ] ->
  ?certificate_file:string ->
  ?key_file:string ->
  ?certificate_string:string ->
  ?key_string:string ->
  ?greeting:bool ->
  ?stop_on_input:bool ->
  ?graceful_stop:bool ->
  handler ->
    unit
(** [Dream.run handler] runs the web application represented by [handler] as a
    web server, by default at {{:http://localhost:8080}
    http://localhost:8080 ↪}. All other arguments are optional. The server runs
    until there is a newline on STDIN. In practice, this means you can stop the
    server by pressing ENTER.

    This function calls {{:https://ocsigen.org/lwt/latest/api/Lwt_main#VALrun}
    [Lwt_main.run↪]} internally, and so is intended to be used as the main loop
    of a program. {!Dream.serve} is a version of [Dream.run] that does not call
    [Lwt_main.run]. Indeed, [Dream.run] is a wrapper around {!Dream.serve}.

    [~interface] and [~port] specify the network interface and port to listen
    on. Use [~interface:"0.0.0.0"] to bind to all interfaces. The default values
    are ["localhost"] and [8080].

    [~stop] is a promise that causes the server to stop when it resolves. The
    server stops accepting new requests. Requests that have already entered the
    web application continue to be processed. The default value is a promise
    that never resolves. However, see also [~stop_on_input].

    [~debug:true] enables debug information in {{!error_page} error templates}.
    It is [false] by default, to help prevent accidental deployment with
    debugging on.

    [~error_handler] receives all errors, including exceptions, [4xx] and [5xx]
    responses, and protocol-level errors. See {{!error_page} Error page} for
    details. The default handler logs all errors, and sends empty responses, to
    avoid accidental leakage of unlocalized strings to the client.

    [~secret] is a key to be used for cryptographic operations. In particular,
    it heavily used for CSRF tokens.

    [~prefix] is a site prefix for applications that are not running at the root
    ([/]) of their domain, and receiving requests with the prefix included in
    the target. A top-most router in the application will check that each
    request has the expected path prefix, and remove it before routing. This
    allows the application's routes to assume that the root is ["/"]. This is
    the first “hop” in Dream's composable routing. The default value is [""]: no
    prefix.

    [~https] enables HTTPS. The default value is [`No]. The other options select
    the TLS library. If using [~https:`OpenSSL], you should install opam package
    `lwt_ssl`. If using [~https:`OCaml_TLS], you should install opam package
    `tls`. In both cases, you should also specify [~certificate_file] and
    [~key_file]. However, for development, Dream includes a compiled-in
    localhost certificate that is completely insecure. It allows testing HTTPS
    without obtaining or generating your own certificates, so using only the
    [~https] argument. The development certificate can be found in
    {{:https://github.com/aantron/dream/tree/master/src/certificate}
    src/certificate/ ↪} in the Dream source code, and reviewed with

    {[
      openssl x509 -in localhost.crt -text -noout
    ]}

    Enabling HTTPS also enables transparent upgrading of connections to HTTP/2,
    if the client requests it. HTTP/2 without HTTPS (known as h2c) is not
    supported by Dream at the moment — but it is also not supported by most
    browsers.

    [~certificate_file] and [~key_file] specify the certificate and key file,
    respectively, when using [~https]. They are not required for development,
    but are required for production. Dream will write a warning to the log if
    you are using [~https], don't provide [~certificate_file] and [~key_file],
    and [~interface] is not ["localhost"].

    [~certificate_string] and [~key_string] allow specifying a certificate and
    key from memory. Dream's handling of these is completely insecure at the
    moment: they are written to temporary files. These arguments are only
    intended for development, for use with an insecure certificate, as a
    fallback in case there is a problem with Dream's built-in development
    certificate, and it is inconvenient to generate separate files.

    The last three arguments, [?greeting], [?stop_on_input], and
    [?graceful_stop] can be used to gradually disable convenience features of
    [Dream.run]. Once all three are disabled, you may want to switch to
    using {!Dream.serve}.

    [~greeting:false] disables the start-up log message that prints a link to
    the web application.

    [~stop_on_input:false] disables stopping the server on input on STDIN.

    [~graceful_stop:false] disables waiting for one second after stop, before
    exiting from [Dream.run], which is done to let already-running request
    handlers complete. *)
(* TODO Consider setting terminal options by default from this function, so that
   they don't have to be set in Makefiles. *)

val serve :
  ?interface:string ->
  ?port:int ->
  ?stop:unit Lwt.t ->
  ?debug:bool ->
  ?error_handler:error_handler ->
  ?secret:string ->
  ?prefix:string ->
  ?https:[ `No | `OpenSSL | `OCaml_TLS ] ->
  ?certificate_file:string ->
  ?key_file:string ->
  ?certificate_string:string ->
  ?key_string:string ->
  handler ->
    unit Lwt.t
(** Same as {!Dream.run}, but returns a promise that does not resolve until the
    server stops listening, instead of calling
    {{:https://ocsigen.org/lwt/latest/api/Lwt_main#VALrun} [Lwt_main.run↪]} on
    it, and lacks some of the higher-level conveniences such as monitoring STDIN
    and graceful exit.

    This function is meant for integrating Dream applications into larger
    programs that have their own procedures for starting and stopping the web
    server.

    All arguments have the same meanings as they have in {!Dream.run}. *)



(** {1:web_formats Web formats} *)

val to_base64url : string -> string
val from_base64url : string -> (string, string) result
(* TODO Test it; document. *)



(** {1 Randomness} *)

val random : int -> string
(** Returns the given number of random bytes. This function uses a
    {{:https://github.com/mirage/mirage-crypto} cryptographically secure random
    number generator ↪}. *)



(** {1 Testing} *)

val request :
  ?client:string ->
  ?method_:method_ ->
  ?target:string ->
  ?version:int * int ->
  ?headers:(string * string) list ->
  string ->
    request
(** [Dream.request body] creates a fresh request with the given body for
    testing. The optional arguments set the corresponding {{!request_fields}
    request fields}. *)

val test : ?prefix:string -> handler -> (request -> response)
(** [Dream.test handler] runs a handler the same way the HTTP server
    ({!Dream.run}) would — assigning it a request id and noting the site root
    prefix, which is used by routers. [Dream.test] calls [Lwt_main.run]
    internally to await the response, which is why the response returned from
    the test is not wrapped in a promise. If you don't need these facilities,
    you can test [handler] by calling it directly with a request. *)

val first : 'a message -> 'a message
(** [Dream.first message] evaluates to the original request or response that
    [message] is immutably derived from. This is useful for getting the original
    state of requests especially, when they were first created inside the HTTP
    server ({!Dream.run}). *)

val last : 'a message -> 'a message
(** [Dream.last message] evaluates to the latest request or response that was
    derived from [message]. This is most useful for obtaining the state of
    requests at the time an exception was raised, without having to instrument
    the latest version of the request before the exception. *)

val sort_headers : (string * string) list -> (string * string) list
(** Sorts headers by name. Headers with the same name are not sorted by value or
    otherwise reordered, because order is significant for some headers. See
    {{:https://tools.ietf.org/html/rfc7230#section-3.2.2} RFC 7230 §3.2.2 ↪} on
    header order. This function can help sanitize output before comparison. *)



(* TODO DOC Give people a tip: a basic response needs either content-length or
   connection: close. *)
(* TODO DOC attempt some graphic that shows what getters retrieve what from the
   response. *)
(* TODO DOC meta description. *)
(* TODO DOC Guidance for Dream libraries: publish routes if you have routes, not
   handlers or middlewares. *)
(* TODO Switch to implicit addition of Content-Length and docuemnt it. *)
(* TODO DOC Need a syntax highlighter. Highlight.js won't work for templates for
   sure. *)
