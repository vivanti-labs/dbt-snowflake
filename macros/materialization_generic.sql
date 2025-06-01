{%- materialization generic, default -%}

  {% set full_refresh_mode = (should_full_refresh()) %}

  {% call statement('main') %}
    {% if full_refresh_mode %}
      create or replace {{ config.require('type') }}
    {% else %}
      create {{ config.require('type') }} if not exists
    {% endif %}
    {{ this }}
    {{ sql }}
    ;
  {% endcall %}

  {{ return({ 'relations': [this] }) }}

{%- endmaterialization -%}
