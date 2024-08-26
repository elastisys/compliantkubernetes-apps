# Configuration Schema

Despite the name, JSON Schema can be used to describe most kinds of data
structures, especially those with a data model very close to JSON, such
as YAML (if you stay away from the fancier features).

A JSON or YAML value that satisfies a schema is called an "instance".

- [JSON Schema Core](https://json-schema.org/draft/2020-12/json-schema-core) specifies the basic structure of a schema.
- [Json Schema Validation](https://json-schema.org/draft/2020-12/json-schema-validation) specifies additional ways to validate various values.

For example, given the following config snippet:

``` yaml
some-service:
  enabled: true
  foo: hello
  bar: [ world ]
```

A schema describing this might look like:

``` yaml
properties:
  some-service:
    title: An Example
    description: Some words to describe this schema
    type: object
    required:
    - enabled
    properties:
      enabled:
        type: boolean
      foo:
        type: string
        examples:
        - hello
        default: baz
      bar:
        type: array
        items:
          type: string
          examples:
          - world
    additionalProperties: false
```

Important things:

`type` declares the accepted type(s) of a value, using the JSON name for types:

- `object`
- `array`
- `string`
- `number` / `integer`
- `boolean`

`title`, `description` and `examples` serve as documentation, to describe the value.
Default values can be provided in `default`.

`type: object` must have a `properties` map describing each value in the object.

Any value not covered by `properties` would be tried against the schema in `additionalProperties`.
In most cases this should be `false`, which causes validation to fail in order to detect e.g. typos or that the schema is  incomplete.
Objects where all properties of are the same kind can have a schema object instead as `additionalProperties`.

Any object property that is **required** can be specified as a list in `required`.
Other properties are allowed to be missing.

Lists, `type: array`, has schema for its items in `items`.

Scalar types can have various constraints and validation hints, e.g. length and range constraints, `format: email` etc. <!-- how much of json-schema-validation to duplicate? -->

The tool `bin/genschema.py` can be used to generate a schema from a YAML snippet.

```bash
cat > conf-snippet.yaml <<EOF
service:
  enabled: true
  features:
  - nice
EOF
./bin/genschema.py ./conf-snippet.yaml | tee ./conf-snippet.yaml
```

The output can be tweaked and inserted into `config/schemas/config.yaml` under `.properties`.

To limit duplication, common properties that are used in many places can be placed under `.$defs` and referenced via `$ref: '#/$defs/thing'`

```yaml
$defs:
  common:
    title: Some Common Thing
service:
  title: The Service
  common:
    $ref: '#/$defs/common'
```

## VSCode

The plugin `redhat.vscode-yaml` can provide auto completion, validation and help texts from the schema.
This can be enabled this in other repositories by editing the file `.vscode/settings.json`, adding the path or URL to the schema under the key `.["yaml.schemas"]` like below:

```json
{
  "yaml.schemas": {
    ".../path/to/ck8s-apps/config/schemas/config.yaml": "config/*-config.yaml"
  }
}
```

## Guidelines

The uses for the schema is to provide structural and conditional validation here in this repository, and to provide reference documentation in the public documentation repository.
To make it easier to read, write, and use the schema we have a set of guidelines to make the most out of it that will follow below.

> [!note]
> The word "schema" here refers to any part of the schema, even subschemas, or schemas in definitions, etc.
>
> The example keys given are within the schema, shortened by stripping any `properties` and `items` components.

### Metadata

These guidelines aim to help in creating better quality reference documentation.

#### Titles

- Must be provided, else it becomes rendered as `Untitled`.
- Should be capitalised, as it becomes part of rendered headers `<title> Schema`.
- Should be short, as it becomes part of rendered names.
- Should be based on the key of the schema, as it becomes more intuitive.
- Should include the context of the schema for common keys, e.g. `Object Storage` and `Object Storage Network Policies`.
- Should include the context type of the schema last, as it becomes part of rendered headers `<title> <type> Schema`.

#### Descriptions

- Must be [GitHub Flavoured Markdown (GFM)](https://github.github.com/gfm/), as it will be rendered down into markdown documentation.
- Should be provided for all complex types, `array` and `object` with `items` or `properties` respectively, and other types of note.
- Should be written with full sentences, including proper punctuation.
- Should include a leading explanation of what the option does and affect.
    - For the root of larger schemas, e.g:
        - `.dex` - "Configure Dex, the federated OpenID connect identity provider."
    - For the root of smaller schemas, e.g.:
        - `.dex.expiry` - "Configure expiry when authenticating via Dex."
    - For the leaf of schemas, e.g.:
        - `.dex.expiry.idToken` - "Configure expiry of id tokens."
- Should include a follow up explanation for more details when required, e.g:
    - `.grafana` - "Compliant Kubernetes hosts two instances of Grafana one for the Platform Administrator and one for the Application Developer"
- Should include a follow up explanation for conditionals, e.g:
    - `.networkPolicies.ingressNginx.ingressOverride` - "When enabled a list of IPs must be set that should override the allowed ingress traffic."
- Should include a follow up explanation for requirements, e.g:
    - `.velero` - "This requires that `.objectStorage` is configured, and will use the bucket or container set in `.objectStorage.buckets.velero`."
- Should include a reference to upstream documentation, and applicable mapping rules, wrapped in a note GFM alert, e.g.:
    - `.fluentd.forwarder.buffer` - "See \[the upstream documentation for reference\]\(\<link\>\), set keys will converted from `camelCase` to `snake_case` as required."
- Should include a note about which cluster it is applicable, either in schema roots as a general case or in schema leafs as an exception, wrapped in a note GFM alert:
    - For the root of larger schemas, e.g.:
        - `.dex` - "Dex is installed in the service cluster, therefore this configuration mainly applies there."
    - For the leaf of schemas, e.g.:
        - `.dex.subdomain` - "Must be set for both service and workload clusters."

#### Defaults and examples

- Must be provided for all simple types, all `array` types, all compositional, conditional, and reusable `object` types.
- Must be valid input to the schema, with the exception of `set-me`.
- Should degrade gracefully, e.g. disabling optional components rather than enabling.

### Structural

These guidelines aim to help in creating schemas that are easier to read and write.

- All schemas must define a type.
- All schemas should define a single type to not cause type confusion.
- All schemas should use `additionalProperties: false` when no additional properties should be defined to make it easier to find misspelled keys.

#### Defines

Defines here refer to the use of `$defs` to define schemas, and `$ref`:s to use schemas.
This is usable in two situations:

1. To reuse common schemas
2. To reduce and flatten nested schemas

- Must be grouped, so documentation can be generated for it, e.g.:
    - `.opensearch.$defs.roles` is not used on its own, but contains schemas that are reused.
- Must be flattened, so documentation can be generated for it, e.g.:
    - `.opensearch.$defs.roles` contains schemas, but those schemas does not define subschemas instead they use `$refs` to other schemas under `.opensearch.$defs.roles`.
- Should be used whenever possible to reuse common schemas, e.g. to have common definitions for similar things like `.grafana.ops` and `.grafana.user`.
- Should be used whenever needed to reduce nested schemas, e.g. to reduce the generated names of a schema which is composed of the path to it within the schema.
- Should be defined under `$defs` local to where they are used, e.g.:
    - `.opensearch.$defs.node` with subschemas reused by `.opensearch.master`, `.opensearch.data`, and `.opensearch.client` node.
    - `.opensearch.$defs.roles` with subschemas reduced and flattened for `.opensearch.extraRoles`.
- Should **not** define titles, descriptions, defaults, or examples unless they are universally applicable.
    - Else it will not be possible to override this metadata when referenced.

#### Imports

Imports here refers to the use of `$defs` to define schemas fetched from upstream sources.
The same guidelines for defines are applicable here as well.

- Must include a comment under the key `$comment` in the schema with the stanza "Schema imported from \[\<upstream-name\>\]\(\<upstream-link\>\).".
- Must include a reference to upstream documentation.

#### Compositions and Conditions

Compositions and conditions here refers to the use of `allOf`, `anyOf`, and `oneOf`, etc. to define schema compositions and conditions.

- Schemas with compositions and conditions must set defaults because otherwise they cannot be fully resolved.
- Schemas with compositions and conditions should set examples because otherwise they cannot be fully resolved.
- Should not use `if`-`then`-`else` as it has less support in tooling, and has a semantic that is generally different from other schema constructs.

<details>
<summary>Examples</summary>

Enabled component have standard properties:

```yaml
anyOf:
    - properties:
        enabled:
            const: false
    - properties:
        enabled:
            const: true
      required:
        - resources
        - nodeSelector
        - tolerations
        - affinity
```

Object storage have associated properties:

```yaml
anyOf:
    - properties:
        type:
            const: azure
      required:
        - azure
    - properties:
        type:
            const: s3
      required:
        - s3
    - properties:
        type:
            const: swift
      required:
        - swift
```

Combining multiple conditions:

```yaml
allOf:
    - anyOf:
        <schema>
    - anyOf:
        <schema>
```

</details>
