{%- materialization empty_table, default -%}

  {% call statement('main') %}
    create table if not exists {{ this }}{{ sql }};
  {% endcall %}
  {{ return({ 'relations': [this] }) }}
{%- endmaterialization -%}
