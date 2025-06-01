{%- materialization external_table, default -%}

  {% set full_refresh_mode = (should_full_refresh()) %}

  {% call statement('main') %}
    {% if full_refresh_mode %}
      create or replace external table
    {% else %}
      create external table if not exists
    {% endif %}
    {{ this }}
    {{ sql }}
    ;
    {% if not full_refresh_mode %}
    alter external table {{ this }} refresh;
    {% endif %}
  {% endcall %}

  {{ return({ 'relations': [this] }) }}

{%- endmaterialization -%}
