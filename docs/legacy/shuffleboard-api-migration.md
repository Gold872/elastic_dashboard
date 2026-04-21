# Shuffleboard API Migration

{% hint style="warning" %}
This can only be done on the 2025 version of Elastic
{% endhint %}

### Code-Driven Layouts

Migrating Shuffleboard API layouts to remote downloading layouts is simple:

1. Clear all tabs and widgets of your dashboard, it is recommended you save your layout to a safe location before doing this step
2. Connect to your robot to populate Elastic with the code-driven layout
3. Export your dashboard layout
4. Set up [remote layout downloading](../additional-features-and-references/remote-layout-downloading.md)

After migrating your layout, it is advised to remove any Shuffleboard API-related code from your robot project.
