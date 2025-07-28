# Postman collection creator
The D365 authorisation token and URL are parameterised so, to make use of this file, you need to either change your Postman parameters to match the names or change the parameters within the file to match your own.
<img width="1206" height="732" alt="image" src="https://github.com/user-attachments/assets/56ef5d5b-50f0-49e1-819d-d48f913365f5" />

## Current limitations
- It is only looking for methods that are decorated with the contract member attribute.
- Contracts that use external class libraries as parameters are also not supported yet.
