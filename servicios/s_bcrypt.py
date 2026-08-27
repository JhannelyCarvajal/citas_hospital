#archivo s_bcrypt
import bcrypt

    ### **************************************************************
    ### Encriptacion de contrasenas. funcion estatica
    ### **************************************************************
def encripta(clave:str)->str:
    bytes = clave.encode('utf-8')
    hashed = bcrypt.hashpw(bytes, bcrypt.gensalt())
    password = hashed.decode('utf-8')
    return password

    ### **************************************************************
    ### Desencripta contrasenas, funcion estatica
    ### **************************************************************
def verifica(clave:str, clave_hashed:str)->bool:   
    clave_evaluar = clave.encode('utf-8')
    hash_bytes = clave_hashed.encode('utf-8')  
    resultado = bcrypt.checkpw(clave_evaluar,hash_bytes)
    return resultado

# .encode("utf-8") -> convierte un str (texto legible) a bytes
# .decode("utf-8") -> hace lo contrario: convierte bytes de vuelta a str.
