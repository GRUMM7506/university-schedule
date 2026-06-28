path = '/home/akbar/Desktop/work/university-schedule/lib/screens/user_management_screen.dart'
with open(path) as f:
    content = f.read()
marker_start = 'class _PermissionsDialogState extends State<_PermissionsDialog> {'
marker_end = 'class _UserDialog extends StatefulWidget {'
start_idx = content.index(marker_start)
end_idx = content.index(marker_end)
print('start', start_idx, 'end', end_idx)
