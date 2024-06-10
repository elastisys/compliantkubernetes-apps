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
