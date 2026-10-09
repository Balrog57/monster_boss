import os
import struct
import zlib

SO_PATH = 'apk-original/boss-monster-2-2-6/lib/armeabi-v7a/libmonodroid_bundle_app.so'
OUT_DIR = 'tools/extracted_assemblies'
os.makedirs(OUT_DIR, exist_ok=True)

with open(SO_PATH, 'rb') as f:
    data = f.read()

# 1. Parse ELF sections
e_shoff = struct.unpack('<I', data[32:36])[0]
e_shentsize = struct.unpack('<H', data[46:48])[0]
e_shnum = struct.unpack('<H', data[48:50])[0]
e_shstrndx = struct.unpack('<H', data[50:52])[0]

sections = []
for i in range(e_shnum):
    sec = data[e_shoff + i*e_shentsize : e_shoff + (i+1)*e_shentsize]
    sh_name, sh_type, sh_flags, sh_addr, sh_offset, sh_size, sh_link, sh_info, sh_addralign, sh_entsize = struct.unpack('<IIIIIIIIII', sec)
    sections.append({'name_idx': sh_name, 'type': sh_type, 'addr': sh_addr, 'offset': sh_offset, 'size': sh_size, 'link': sh_link, 'entsize': sh_entsize})

shstr = data[sections[e_shstrndx]['offset'] : sections[e_shstrndx]['offset'] + sections[e_shstrndx]['size']]
for s in sections:
    end = shstr.find(b'\x00', s['name_idx'])
    s['name'] = shstr[s['name_idx']:end].decode()

# Build symbol dictionary
sym_map = {}
for s in sections:
    if s['type'] in (2, 11): # SHT_SYMTAB, SHT_DYNSYM
        strtab = sections[s['link']]
        strdata = data[strtab['offset']:strtab['offset']+strtab['size']]
        num_syms = s['size'] // s['entsize']
        for i in range(num_syms):
            sym = data[s['offset'] + i*16 : s['offset'] + (i+1)*16]
            st_name, st_value, st_size, st_info, st_other, st_shndx = struct.unpack('<IIIBBH', sym)
            name_end = strdata.find(b'\x00', st_name)
            name = strdata[st_name:name_end].decode('latin1')
            if name.startswith('assembly_data_'):
                sym_map[name] = (st_value, st_size, st_shndx)

# 2. Parse bundled_assemblies table
def cstr(off):
    end = data.find(b'\x00', off)
    return data[off:end].decode('latin1')

cur = 3148128
extracted = []
for i in range(50):
    name_off, zero, uncomp_size, comp_size = struct.unpack('<IIII', data[cur:cur+16])
    if name_off == 0:
        break
    dll_name = cstr(name_off)
    if not dll_name.endswith('.dll'):
        break
    
    sym_name = 'assembly_data_' + dll_name.replace('.', '_').replace('-', '_')
    if sym_name not in sym_map:
        print(f"Warning: symbol {sym_name} not found!")
        cur += 16
        continue
    
    st_value, st_size, st_shndx = sym_map[sym_name]
    sec_target = sections[st_shndx]
    file_offset = sec_target['offset'] + (st_value - sec_target['addr'])
    raw_gz = data[file_offset : file_offset + st_size]
    
    decomp = zlib.decompress(raw_gz, 15 + 32)
    out_file = os.path.join(OUT_DIR, dll_name)
    with open(out_file, 'wb') as out_f:
        out_f.write(decomp)
    
    extracted.append((dll_name, len(decomp), st_size))
    cur += 16

print(f"Extracted {len(extracted)} assemblies to {OUT_DIR}:")
for name, uncompressed, compressed in sorted(extracted, key=lambda x: -x[1]):
    print(f" - {name:35s}: {uncompressed:8d} bytes (compressed: {compressed:7d} bytes)")
