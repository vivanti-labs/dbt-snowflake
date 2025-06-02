{%- materialization task, default -%}

  {% call statement('main') %}
    create or replace task
    {{ this }}
    {{ sql }}
    ;

    {%- set running = config.get('running', false) -%}
    {%- if running %}
    alter task {{ this }} resume;
    {% endif -%}
  {% endcall %}

  {{ return({ 'relations': [this] }) }}

{%- endmaterialization -%}
