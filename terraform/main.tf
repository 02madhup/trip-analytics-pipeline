terraform {
  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 1.0"
    }
  }
}


provider "snowflake" {
  organization_name = "YDDMBXL"
  account_name       = "PZ24011"
}

resource "snowflake_warehouse" "trip_analytics_wh" {
  name                = "TRIP_ANALYTICS_WH"
  warehouse_size      = "XSMALL"
  auto_suspend        = 30
  auto_resume         = true
  initially_suspended = true
}

resource "snowflake_database" "trip_analytics_db" {
  name    = "TRIP_ANALYTICS"
  comment = "Database for real-time trip analytics pipeline"
}

resource "snowflake_schema" "staging" {
  database = snowflake_database.trip_analytics_db.name
  name     = "STAGING"
}

resource "snowflake_schema" "analytics" {
  database = snowflake_database.trip_analytics_db.name
  name     = "ANALYTICS"
}

resource "snowflake_account_role" "dbt_role" {
  name    = "DBT_TRANSFORMER"
  comment = "Role used by dbt to run transformations, scoped to only what it needs"
}

resource "snowflake_grant_privileges_to_account_role" "dbt_warehouse_usage" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges         = ["USAGE", "OPERATE"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.trip_analytics_wh.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "dbt_database_usage" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges         = ["USAGE", "CREATE SCHEMA"]
  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.trip_analytics_db.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "dbt_staging_schema" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges         = ["USAGE", "CREATE TABLE", "CREATE VIEW"]
  on_schema {
    schema_name = "\"${snowflake_database.trip_analytics_db.name}\".\"${snowflake_schema.staging.name}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "dbt_analytics_schema" {
  account_role_name = snowflake_account_role.dbt_role.name
  privileges         = ["USAGE", "CREATE TABLE", "CREATE VIEW"]
  on_schema {
    schema_name = "\"${snowflake_database.trip_analytics_db.name}\".\"${snowflake_schema.analytics.name}\""
  }
}

resource "snowflake_grant_account_role" "dbt_role_to_user" {
  role_name = snowflake_account_role.dbt_role.name
  user_name = "MADHUP"
}