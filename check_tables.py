import asyncpg, asyncio

async def main():
    conn = await asyncpg.connect(host='192.168.1.201', port=5432, user='postgres', password='1', database='bd_hospital')
    rows = await conn.fetch("SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename")
    print("=== Tablas en la nueva BD ===")
    for r in rows:
        print(r['tablename'])
    await conn.close()

asyncio.run(main())
