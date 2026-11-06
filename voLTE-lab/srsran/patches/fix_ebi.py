from pathlib import Path

p = Path('/srsran/srsue/src/stack/upper/nas.cc')
s = p.read_text()

anchor = (
    '    liblte_mme_unpack_activate_default_eps_bearer_context_request_msg(&attach_accept.esm_msg,\n'
    '                                                                      &act_def_eps_bearer_context_req);\n'
)
assert anchor in s, 'anchor no encontrado'
override = (
    '\n'
    '    // CIERRE-V7: Open5GS asigna EBI=5/PTI=1, pero el parser de srsUE\n'
    '    // entrega EBI corrupto (9). Forzar antes de setup_if_addr mantiene\n'
    '    // coherentes el TUN, el bearer manager y el Attach Complete.\n'
    '    act_def_eps_bearer_context_req.eps_bearer_id = 5;\n'
    '    act_def_eps_bearer_context_req.proc_transaction_id = 1;\n'
)
s = s.replace(anchor, anchor + override, 1)

old_call = '      send_attach_complete(transaction_id, bearer.eps_bearer_id);'
new_call = (
    '      send_attach_complete(act_def_eps_bearer_context_req.proc_transaction_id,\n'
    '                           act_def_eps_bearer_context_req.eps_bearer_id);'
)
assert old_call in s, 'call no encontrado'
s = s.replace(old_call, new_call, 1)
p.write_text(s)
print('srsUE patched: EBI 5/PTI 1')
