from credentials import DB_PARAMS, SCHEMA
import os
import requests
import psycopg2
import csv
import geojson
from datetime import datetime
from urllib.request import urlretrieve

# URL to fetch the JSON file
JSON_URL = "https://apps.cnt.org/water-data-tool-staging/data/data.json"

def fetch_json(url):
    response = requests.get(url)
    response.raise_for_status()
    return response.json()

def get_last_import_dates(conn):
    query = f"""
        SELECT file_url, max(last_import_date) as last_import_date 
        FROM {SCHEMA}.file_import_tracker 
        group by file_url;
    """
    with conn.cursor() as cur:
        cur.execute(query)
        return {row[0]: row[1] for row in cur.fetchall()}

def update_last_import_date(conn, file_url, import_date):
    query = f"""
        INSERT INTO {SCHEMA}.file_import_tracker (file_url, last_import_date)
        VALUES ('{file_url}', '{import_date}');
    """
    with conn.cursor() as cur:
        cur.execute(query)
        conn.commit()

def rename_existing_table(conn, table_name):
    new_table_name = f"{table_name}_{datetime.now().strftime('%Y%m%d%H%M%S')}"
    check_query = f"SELECT to_regclass('{SCHEMA}.{table_name}');"
    with conn.cursor() as cur:
        cur.execute(check_query)
        if cur.fetchone()[0] is not None:  # Table exists
            query = f"ALTER TABLE {SCHEMA}.{table_name} RENAME TO {new_table_name};"
            cur.execute(query)
            conn.commit()
        else:
            print(f"Table {table_name} does not exist. Skipping rename.")



def import_csv_to_db(conn, file_url, table_name):
    file_nm = f"{table_name}.csv"
    # Download the file
    urlretrieve(file_url, file_nm)

    rename_existing_table(conn, table_name)

    cursor = conn.cursor()

    # Create the table based on the CSV structure
    with open(file_nm, 'r') as file:
        reader = csv.reader(file)
        header = next(reader)  # Get the header row
        
        column_definitions = []
        for column_name in header:
            cleaned_name = column_name.replace(' ','_').replace('.','_').replace('/','').replace(',','').replace('%','pct').replace('(','').replace(')','').replace('&','_').replace('<','lt_').replace('>','gt_').replace('$','').replace('-','_').replace('?','')
            cleaned_name = cleaned_name.replace('_____','_').replace('____','_').replace('___','_').replace('__','_').lower()
            if cleaned_name.endswith('_'):
                cleaned_name = cleaned_name[:-1]
            # Assume all columns are TEXT by default
            column_definitions.append(f"{cleaned_name} TEXT")


        create_table_query = f"""
            CREATE TABLE IF NOT EXISTS {SCHEMA}.{table_name} (
                {', '.join(column_definitions)}
            )
        """
        cursor.execute(create_table_query)

    # Open the CSV file and insert the data
    with open(file_nm, 'r') as file:
        reader = csv.reader(file)
        next(reader)  # Skip the header row
        for row in reader:
            values = [] #build values array to handle NA values
            for value in row:
                if value == "NA":
                    values.append("NULL")  # SQL NULL (no quotes)
                else:
                    # wrap other values in single quotes, escaping internal quotes
                    escaped = value.replace("'", "''")
                    values.append(f"'{escaped}'")

            insert_query = f"""
                INSERT INTO {SCHEMA}.{table_name} VALUES ({', '.join(values)});
            """
            cursor.execute(insert_query)

    # Commit the changes and close the connection
    conn.commit()
    cursor.close()

    print("Records inserted successfully.", file_nm, table_name)

    # Clean up the downloaded CSV file
    os.remove(file_nm)


def import_geojson_to_db(conn, file_url, table_name):
    file_nm = f"{table_name}.geojson"
    # Download the file
    urlretrieve(file_url, file_nm)

    # Read the GeoJSON file
    with open(file_nm) as f:
        data = geojson.load(f)

    rename_existing_table(conn, table_name)
    # Get properties from the first feature
    properties = data['features'][0]['properties'].keys() if data['features'] else []
    
    # Create a table with columns for each property
    columns = ', '.join([f"{key.replace(' ','_')} TEXT" for key in properties])
    create_table_query = f"""
        DROP TABLE IF EXISTS {SCHEMA}.{table_name};
        CREATE TABLE {SCHEMA}.{table_name} (
            gid SERIAL PRIMARY KEY,
            geom GEOMETRY(MULTIPOLYGON, 4326),
            {columns}
        );
    """
    with conn.cursor() as cur:
        cur.execute(create_table_query)
        conn.commit()

    with conn.cursor() as cur:
        for feature in data['features']:
            geom = geojson.loads(geojson.dumps(feature['geometry']))
            values = [feature['properties'].get(key, None) for key in feature['properties']]
            # Use %s placeholders for each property value
            placeholders = ', '.join(['%s'] * len(values))
            cur.execute(f"""
                INSERT INTO {SCHEMA}.{table_name} (geom, {', '.join(feature['properties'].keys()).replace(' ','_')})
                VALUES (ST_SetSRID(ST_GeomFromGeoJSON(%s), 4326), {placeholders});
            """, (geojson.dumps(geom), *values))
        conn.commit()

    print("Records inserted successfully.", file_nm, table_name)

    # Clean up the downloaded CSV file
    os.remove(file_nm)


def main():
    # Connect to the database
    conn = psycopg2.connect(**DB_PARAMS)
    try:
        # Fetch JSON data
        data = fetch_json(JSON_URL)
        last_import_dates = get_last_import_dates(conn)

        for file_info in data:
            file_url = file_info['http_path']
            last_updated = datetime.strptime(file_info['last_updated'], '%Y-%m-%d %H:%M:%S')
            table_name = file_url.split('/')[-1].rsplit('.', 1)[0] 

            # Check if the file needs to be updated
            print(f"Processing file: {file_url} (Last updated: {last_updated})")
            print(f"Current last import date: {last_import_dates.get(file_url, 'Never')}")

            if file_url not in last_import_dates or last_updated > last_import_dates[file_url]:
                if file_url.endswith('.csv'):
                    import_csv_to_db(conn, file_url, table_name)
                elif file_url.endswith('.geojson'):
                    import_geojson_to_db(conn, file_url, table_name)
                else:
                    print(f"Unsupported file format: {file_url}")
                    continue

                # Update the last import date
                update_last_import_date(conn, file_url, last_updated)
                print(f"Imported and updated: {file_url}")
            else:
                print(f"No update needed for: {file_url}")
    finally:
        conn.close()

if __name__ == "__main__":
    main()