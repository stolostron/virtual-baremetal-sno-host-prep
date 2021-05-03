# Setup Observability

1. Create all.yml:
```
cp vars/all.sample.yml vars/all.yml
```

2. Fill in all.yml according to the comments.

3. Create a inventory file. All hosts should be ssh accessible:
```
cat << EOF > inventory
[bastion]
host-name-of-bastion
EOF
```

4. Start:
```
ansible-playbook -i inventory ansible/enable_obs.yml
```