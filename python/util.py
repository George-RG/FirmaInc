import sys
import psycopg2
import hashlib
import contextlib

@contextlib.contextmanager
def db_connection(psql_ip):
    try:
        dbh = psycopg2.connect(database="firmware",
                               user="firmadyne",
                               password="firmadyne",
                               host=psql_ip)
        yield dbh
    except Exception as e:
        sys.stderr.write(f"Error connecting to database: {e}")
    finally:
        if 'dbh' in locals():
            dbh.close()

def io_md5(target):
    blocksize = 65536
    hasher = hashlib.md5()

    with open(target, 'rb') as ifp:
        buf = ifp.read(blocksize)
        while buf:
            hasher.update(buf)
            buf = ifp.read(blocksize)
        return hasher.hexdigest()


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
    
def get_brand(infile, psql_ip):
    md5 = io_md5(infile)
        
    with db_connection(psql_ip) as dbh:
        cur = dbh.cursor()
        cur.execute("SELECT brand_id FROM image WHERE hash = %s", (md5,))
        brand_id = cur.fetchone()

        if brand_id:
            cur.execute("SELECT name FROM brand WHERE id = %s", (brand_id[0],))
            brand = cur.fetchone()
            if brand:
                return brand[0]
    
    return "unknown"

def get_iid(infile, psql_ip):
    md5 = io_md5(infile)
    
    with db_connection(psql_ip) as dbh:
        cur = dbh.cursor()
        cur.execute("SELECT id FROM image WHERE hash = %s", (md5,))
        image_id = cur.fetchone()
    if image_id:
        return image_id[0]
    
    return ""

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
        
    elif sys.argv[1] == 'get_brand':
        if len(sys.argv) != 4:
            print("Usage: python utility.py get_brand [psql_ip] [infile]")
            sys.exit(1)
        print(get_brand(infile, psql_ip))
        
    elif sys.argv[1] == 'get_iid':
        if len(sys.argv) != 4:
            print("Usage: python utility.py get_iid [psql_ip] [infile]")
            sys.exit(1)
        print(get_iid(infile, psql_ip))
        