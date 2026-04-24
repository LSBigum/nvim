; Restrict context in C++ to namespaces and function signatures.
(namespace_definition
  body: (_) @context.end) @context

(function_definition
  body: (compound_statement) @context.end) @context
