# Pull Request

## Description
Brief description of the changes in this PR.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Security improvement
- [ ] Performance improvement

## Related Issues
Fixes #(issue number)

## Changes Made
- [ ] Added/modified Bicep templates
- [ ] Updated parameter files
- [ ] Modified deployment scripts
- [ ] Updated documentation
- [ ] Added/updated tests

## Affected Modules
List the modules that were changed:
- [ ] networking/
- [ ] security/
- [ ] compute/
- [ ] data/
- [ ] monitoring/
- [ ] shared/

## Testing Checklist
- [ ] Template validation passed (`.\scripts\validate.ps1`)
- [ ] Security scan passed (Checkov)
- [ ] Compute module tests passed (`.\scripts\test-compute-modules.ps1`)
- [ ] Data layer module tests passed (`.\scripts\test-data-layer.ps1`)
- [ ] Private endpoints tests passed (`.\scripts\test-private-endpoints.ps1`)
- [ ] Deployed successfully in development environment
- [ ] All existing functionality still works
- [ ] New functionality works as expected

## Security Checklist
- [ ] No secrets or sensitive data committed
- [ ] Security best practices followed
- [ ] Checkov scan results reviewed and addressed
- [ ] Access controls properly configured
- [ ] Network security rules validated

## Documentation
- [ ] README updated (if needed)
- [ ] CHANGELOG updated
- [ ] Inline code documentation added/updated
- [ ] Parameter descriptions added/updated

## Deployment Testing
**Environment tested:** [dev/staging/prod]
**Resource Group:** [resource-group-name]
**Region:** [azure-region]

**Test Results:**
- [ ] All resources deployed successfully
- [ ] Network connectivity verified
- [ ] Security configurations validated
- [ ] Monitoring and logging working

## Screenshots/Outputs
If applicable, add screenshots or command outputs to help explain your changes.

## Additional Notes
Add any additional notes, considerations, or context for reviewers.