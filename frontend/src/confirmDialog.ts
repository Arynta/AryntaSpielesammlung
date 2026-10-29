// Eigene Ja/Nein-Abfrage im Stil der Seite statt window.confirm().
// Das <dialog>-Element bringt Fokusfalle, Escape-Taste und Screenreader-Rolle schon mit.

let dialog: HTMLDialogElement | null = null;

function ensureDialog(): HTMLDialogElement {
  if (dialog) return dialog;
  dialog = document.createElement("dialog");
  dialog.className = "confirm";
  dialog.setAttribute("aria-labelledby", "confirm-question");
  dialog.innerHTML = `
    <p id="confirm-question" class="confirm-question"></p>
    <div class="confirm-buttons">
      <button class="btn" value="no" data-confirm="no"></button>
      <button class="btn primary" value="yes" data-confirm="yes"></button>
    </div>`;
  // Außerhalb von #app, damit das Neuzeichnen der Seite den offenen Dialog nicht entfernt
  document.body.append(dialog);
  return dialog;
}

export function askConfirm(question: string, confirmLabel: string, cancelLabel = "Nein"): Promise<boolean> {
  const el = ensureDialog();
  el.querySelector(".confirm-question")!.textContent = question;
  const noButton = el.querySelector<HTMLButtonElement>('[data-confirm="no"]')!;
  const yesButton = el.querySelector<HTMLButtonElement>('[data-confirm="yes"]')!;
  noButton.textContent = cancelLabel;
  yesButton.textContent = confirmLabel;

  return new Promise((resolve) => {
    const finish = (answer: boolean) => {
      noButton.onclick = null;
      yesButton.onclick = null;
      el.oncancel = null;
      el.close();
      resolve(answer);
    };
    noButton.onclick = () => finish(false);
    yesButton.onclick = () => finish(true);
    el.oncancel = (event) => {
      event.preventDefault();
      finish(false);
    };
    el.showModal();
    // Bei Fragen, die etwas kaputtmachen können, steht der Fokus sicherheitshalber auf "Nein"
    noButton.focus();
  });
}
