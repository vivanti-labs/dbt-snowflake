{%- materialization materialized_view, default -%}

  {% set full_refresh_mode = (should_full_refresh()) %}

  {% call statement('main') %}
    {% if full_refresh_mode %}
      create or replace materialized view
    {% else %}
      create materialized view if not exists
    {% endif %}
    {{ this }}
    as {{ sql }}
    ;
  {% endcall %}

  {{ return({ 'relations': [this] }) }}

{%- endmaterialization -%}
