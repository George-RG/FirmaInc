import sys
import psycopg2
import hashlib

def check_connection(psql_ip):
    try:
        dbh = psycopg2.connect(database="firmware",
                               user="firmadyne",
                               password="firmadyne",
                               host=psql_ip)
        dbh.close()
        return 0
    except:
        return 1

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python utility.py [command] [psql_ip] (infile)")
        sys.exit(1)
    
    if len(sys.argv) == 4:
        infile = sys.argv[3]
    
    psql_ip = sys.argv[2]
    
    if sys.argv[1] == 'check_connection':
        print("Checking connection to PostgreSQL database...")
        exit(check_connection(psql_ip))
        