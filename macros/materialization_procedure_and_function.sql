{%- materialization procedure, default -%}

  {% call statement('main') %}
    {%- for previous in config.get('previously', []) -%}
    drop procedure if exists {{ this }}{{ previous }};
    {%- endfor -%}

    create or replace procedure {{ this }}{{ sql }};

    {%- set signature = config.get('signature', '()') -%}
    {%- set grants = config.get('grants', {}) -%}
    {%- for priv,roles in grants.items() -%}
    {%- for role in roles %}
    grant {{ priv }} on procedure {{ this }}{{ signature }} to role {{ role }};
    {%  endfor -%}
    {%- endfor -%}

  {% endcall %}
  {{ return({ 'relations': [this] }) }}

{%- endmaterialization -%}

{%- materialization function, default -%}

  {% call statement('main') %}
    {%- for previous in config.get('previously', []) -%}
    drop function if exists {{ this }}{{ previous }};
    {%- endfor -%}

    create or replace function {{ this }}{{ sql }};

    {%- set signature = config.get('signature', '()') -%}
    {%- set grants = config.get('grants', {}) -%}
    {%- for priv,roles in grants.items() -%}
    {%- for role in roles %}
    grant {{ priv }} on function {{ this }}{{ signature }} to role {{ role }};
    {%  endfor -%}
    {%- endfor -%}

  {% endcall %}
  {{ return({ 'relations': [this] }) }}

{%- endmaterialization -%}
